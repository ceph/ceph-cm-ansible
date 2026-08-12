# Alloy Role

Installs and configures **Grafana Alloy** to ship logs from the lab's bare-metal
and VM infra hosts to the LokiStack running on the pok OpenShift cluster.

This is the logs counterpart to the `grafana_agent` role, which handles metrics.
The two coexist on the same hosts.

## Why a separate role instead of extending `grafana_agent`

Grafana Agent static mode went EOL in November 2025 and no longer receives
security fixes. Alloy is its supported successor. Shipping an EOL agent as the
collector for a security audit trail is the wrong tradeoff, so logs go to Alloy
even though metrics still run through grafana-agent.

A follow-up can fold the node_exporter scrape and Mimir `remote_write` into the
same Alloy instance and retire grafana-agent entirely.

## What it collects — and what it does not

**It does not collect all of `/var/log`.** Alloy collects only what is declared.
Three sources:

1. **The systemd journal** (`loki.source.journal`) — the primary source. Covers
   sshd, sudo, su, systemd units, the kernel, cron, and anything a service logs
   to stdout under systemd. This is most of what people mean by "`/var/log`".
2. **`/var/log/audit/audit.log`** — auditd, declared explicitly because it does
   not go through the journal.
3. **`alloy_extra_log_paths`** — a per-group allowlist of globs, for apps that
   write to disk instead of the journal.

Deliberately excluded:

| Excluded | Reason |
| --- | --- |
| `/var/log/messages`, `secure`, `cron` (RHEL)<br>`/var/log/syslog`, `auth.log` (Debian) | rsyslog *copies of the journal*. Collecting both double-ingests every line. |
| `/var/log/wtmp`, `btmp`, `lastlog`, `tallylog` | Binary. The login events are already in the journal as text. |
| `/var/log/journal/**` | The binary journal, already read via `loki.source.journal`. |
| `*.gz`, `*.1`, `*.[0-9]` | Rotated files — tailing them re-ingests the whole history on every logrotate run. |

If a service writes to a file outside the journal and isn't in
`alloy_extra_log_paths`, it will not be collected until someone adds the glob.
That's the intended tradeoff: predictable volume and no duplicate ingest, at the
cost of having to name things.

## Supported platforms

- Debian / Ubuntu
- RHEL and derivatives (Rocky, AlmaLinux, CentOS Stream)

## Prerequisites

Three things must exist in the secrets repo before this role will run:

### 1. `loki_token.yml` — the push token

A ServiceAccount bearer token for the `sepia-hosts` SA in the cluster's
`openshift-logging` namespace, scoped to `create` on the `infrastructure` tenant
only. It cannot read logs back and cannot touch the audit tenant.

Use the **long-lived** token from the `sepia-hosts-token` Secret, not
`oc create token` — the latter defaults to a one-hour lifetime, so every host
would stop shipping an hour after the play ran.

```bash
oc -n openshift-logging get secret sepia-hosts-token \
  -o jsonpath='{.data.token}' | base64 -d
```

Store it vault-encrypted as `loki_push_token`:

```yaml
# ceph-sepia-secrets/ansible/loki_token.yml
loki_push_token: "eyJhbGciOi..."
```

### 2. `files/lokistack-ingress-ca.crt` — the cluster ingress CA

The gateway route is served by the cluster's self-signed ingress certificate
(`CN=ingress-operator@...`), so the host CA bundle will not verify it. Extract
the CA once:

```bash
oc get cm -n openshift-config-managed default-ingress-cert \
  -o jsonpath='{.data.ca-bundle\.crt}' \
  > ceph-sepia-secrets/ansible/files/lokistack-ingress-ca.crt
```

> **This expires.** When the ingress certificate rotates, every host stops
> shipping at once and does so quietly — the failure shows up in
> `journalctl -u alloy`, not anywhere you'd normally look. Re-extract and re-run
> the play when that happens.

We deliberately do *not* use `insecure_skip_verify` here, even though the
`grafana_agent` role does for Mimir. That's tolerable for metrics; it isn't for
the transport carrying an audit trail.

### 3. Per-group `alloy_extra_log_paths` (optional)

```yaml
# ceph-sepia-secrets/ansible/inventory/group_vars/public_facing.yml
alloy_extra_log_paths:
  - /var/log/nginx/*.log
  - /var/log/apache2/*.log
```

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `alloy_listen_addr` | `127.0.0.1:12346` | Alloy's HTTP server. **Not** the default 12345 — see below. |
| `alloy_lokistack_host` | `logging-loki-openshift-logging.apps.pok.os.sepia.ceph.com` | Gateway route |
| `alloy_tenant` | `infrastructure` | LokiStack tenant. Part of the URL path, not a header. |
| `alloy_journal_max_age` | `12h` | Cold-start backlog limit |
| `alloy_collect_auditd` | `true` | Auto-skipped on hosts without auditd |
| `alloy_extra_log_paths` | `[]` | Allowlist of extra globs to tail |
| `alloy_log_level` | `warn` | Alloy's own log level |

## Things this role has to work around

**Port collision with grafana-agent.** Both default their HTTP server to
`127.0.0.1:12345`. Every host in scope already runs grafana-agent, so the role
sets `CUSTOM_ARGS` in `/etc/default/alloy` (Debian) or `/etc/sysconfig/alloy`
(RHEL) to move Alloy to 12346. Without this, Alloy fails to bind and never
starts.

**Journal access.** The `alloy` user is added to `systemd-journal` (full journal
rather than just its own entries), and to `adm` on Debian/Ubuntu for
group-readable files under `/var/log`.

**auditd access.** `/var/log/audit/audit.log` is `0600 root:root` inside a `0700`
directory, so group membership alone can't reach it. The role sets
`log_group = alloy` in `/etc/audit/auditd.conf`, which makes auditd itself relax
the file to `0640 root:alloy` and the directory to `0750` — and, unlike a manual
`chmod`, that survives log rotation. auditd is then restarted via `service auditd
restart`, because it refuses `systemctl restart` on RHEL.

**SELinux.** Alloy's RPM ships no SELinux policy, so it runs as
`unconfined_service_t`, which can generally read `auditd_log_t` under the targeted
policy. Verify on one RHEL host before rolling to the fleet — check for denials
with `ausearch -m avc -ts recent`. If it does get denied, `roles/grafana_agent`
has the precedent for shipping a custom policy module
(`files/grafana/customuseradd.te` + `tasks/useradd-selinux.yml`).

## Usage

Test against one host of each family first:

```bash
ansible-playbook alloy.yml --limit store01.front.sepia.ceph.com
```

Then roll out one group at a time, leaving `ci_infrastructure` (the Jenkins
builders — the noisiest hosts in the fleet) for last:

```bash
ansible-playbook alloy.yml --limit infrastructure
```

`alloy.yml` covers 205 hosts: `infrastructure`, `ci_infrastructure`,
`public_facing`, `long_running_cluster`, and the perf/dev boxes (`officinalis`,
`mako`, `folio`, `sockeni`, `vossi`). The pattern explicitly excludes
`infra_compute`, `infra_storage` and `cnv` — those are the pok cluster's own
RHCOS nodes, which the in-cluster ClusterLogForwarder already collects. Testnodes
are not in any of these groups.

## Verifying

On the host:

```bash
systemctl status alloy grafana-agent   # both active
ss -lntp | grep 1234                   # 12345 and 12346, no conflict
journalctl -u alloy -n 50              # no permission-denied, no 401/403
```

In Grafana or the OpenShift console Logs view:

```logql
{origin="baremetal", host="store01.front.sepia.ceph.com"}
{job="auditd", host="store01.front.sepia.ceph.com"}
```

An empty result for the second query with a healthy service usually means the
auditd permission work didn't take — check `journalctl -u alloy` for
permission-denied on `/var/log/audit/audit.log`.

Then confirm you aren't double-ingesting: `{job="varlog"}` should not be
returning lines that also show up under `{job="systemd-journal"}`. If it is, a
`messages`/`syslog`-style path has crept into an `alloy_extra_log_paths`.

### Read the HTTP status before blaming the host

`journalctl -u alloy | grep 'sending batch'` gives the real reason a push failed,
and the status code says which layer is at fault:

| Status | Meaning |
| --- | --- |
| `401` / `403` | Token wrong, expired, or missing the tenant ClusterRole. Re-check `loki_push_token`. |
| x509 / TLS error | `files/lokistack-ingress-ca.crt` is stale — the cluster ingress cert rotated. Re-extract it. |
| **`429`** | **Nothing is wrong with this host.** The LokiStack `infrastructure` tenant is out of budget — see below. |

**The 429 case matters most**, because it looks like a host problem and isn't.
These hosts push into the same `infrastructure` tenant the OpenShift cluster uses
for its own node and container logs. When that tenant is congested — hitting
`maxGlobalStreamsPerTenant` or `ingestionRate` — every bare-metal host is locked
out with:

```
status=429 error="maximum active stream limit exceeded when trying to create stream"
```

This happened on the very first soko05 deployment. The cluster was replaying a
large log backlog, which made Loki create ~169 `__time_shard__` values and
multiply its real streams into ~97,000 against a 50,000 cap. No bare-metal host
could get in until it drained. The host side was entirely healthy — a 429 rather
than a 403 is in fact proof the token and CA are correct.

Diagnose from the cluster, not the host:

```bash
oc -n openshift-logging get lokistack logging-loki -o jsonpath='{.spec.limits}'
```

and against Thanos: `sum by (tenant) (loki_ingester_memory_streams)` and
`sum by (tenant,reason) (rate(loki_discarded_bytes_total[5m]))`.

Chasing this by raising limits is a trap — the fleet shares a tenant with the
cluster, so the durable fix is isolating the pipelines, not out-running the load.

## Dependencies

The `secrets` role, which provides `secrets_path`.
