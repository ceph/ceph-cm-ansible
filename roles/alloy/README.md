# Alloy Role

Installs and configures **Grafana Alloy** on the lab's bare-metal and VM infra
hosts. One Alloy instance per host runs two independent pipelines:

| Pipeline | Source | Destination | Switch |
| --- | --- | --- | --- |
| **metrics** | node_exporter on `localhost:9100` | Mimir on the pok OpenShift cluster | `alloy_metrics_enabled` |
| **logs** | systemd journal, `/var/log/audit/audit.log`, per-group allowlist | LokiStack on the pok OpenShift cluster | `alloy_logs_enabled` |

The metrics pipeline is what `roles/grafana_agent` used to do. **This role
removes grafana-agent** (service, package, config, WAL, user) from every host it
runs on -- grafana-agent static mode went EOL in November 2025 and no longer
receives security fixes, and Alloy is its supported successor. The old role and
`grafana_agent.yml` are gone; `alloy.yml` replaces them.

## Metrics: node_exporter -> Mimir

Every host the role runs on gets the distro node_exporter
(`prometheus-node-exporter` on Debian/Ubuntu, `node_exporter` from EPEL on
RHEL-family), scraped by Alloy on localhost every 60s and pushed to Mimir with
basic auth. That is what puts a host in the **Node Exporter Full** dashboard
(grafana.com 1860, deployed as `jenkins-grafana/dashboards/node-exporter-lab.yaml`
in `ceph/sepia-openshift`) and under the provisioned node-exporter alerts.

### The label contract

The dashboard and alerts select hosts by three labels, and the role emits them
**exactly as grafana-agent did**:

| Label | Value | Why it's this |
| --- | --- | --- |
| `job` | `node` | What dashboard 1860's `$job` variable and every alert filter on. |
| `instance` | `<inventory_hostname>:9100` | Dashboard's `$node` variable. Alerts match literal values (`instance=~"[123].chacra.ceph.com:9100"`, `instance="soko04.front.sepia.ceph.com:9100"`). |
| `nodename` | `<inventory_hostname>` | Dashboard's `$nodename` variable (`node_uname_info{job="$job"}` by `nodename`). |
| `host` | `inventory_hostname` | The same name on both pipelines, so metrics and logs join on one label. |

Everything is `inventory_hostname` -- the canonical name from the sepia
inventory -- never `ansible_fqdn`. grafana-agent used `ansible_fqdn`, which
reflects whatever `/etc/hostname` and the resolver say and therefore drifts:
during the 2026-09 rollout the adami hosts silently flipped from
`.front.sepia.ceph.com` to `.maas` because MAAS DNS changed underneath them,
orphaning their series and proving the "continuity" it offered was an illusion.
The provisioned node-exporter alerts in `ceph/sepia-openshift` match these
instance values; if you change `alloy_node_instance`, update the alert
expressions there in the same change or they silently unhook. (During the
fqdn->inventory_hostname cutover the alerts matched both spellings, so no
alert went NoData; the old-spelling halves can be dropped once the stale
series age out.)

### When the role does not install node_exporter

If something already listens on `:9100` and the distro package is not installed,
the role leaves it alone and scrapes what's there. That's the cephadm
node-exporter container on the LRC hosts (`long_running_cluster`); installing the
distro package next to it would leave two exporters fighting over the port after
every reboot. Set `alloy_manage_node_exporter: false` to force the same
behaviour on a host or group.

### Mimir endpoint and TLS

`agent_mimir_url` defaults to the in-lab route
(`https://mimir-jenkins-monitoring.apps.pok.os.sepia.ceph.com/api/v1/push`);
`group_vars/public_facing.yml` in the secrets repo overrides it with the
internet-facing `https://mimir.ceph.com/api/v1/push`. The variable name is
unchanged from the grafana_agent role so that override keeps working. (The old
role had lost this default in 7cb459c, leaving every non-public_facing host
with an undefined URL; hosts deployed before that still run with this value.)

Basic auth is added only when both `mimir_username` and `mimir_password` are
defined -- the vault-encrypted `mimir_password.yml` is included for that, same
as before. Neither Mimir endpoint enforces it today, and no deployed
grafana-agent config carries it.

TLS is verified. The in-cluster route is served by the same pok ingress CA as the
LokiStack gateway, so it's checked against `files/lokistack-ingress-ca.crt`;
`mimir.ceph.com` has a public certificate and uses the system bundle.
grafana-agent used `insecure_skip_verify` here; there is no reason to.
`alloy_mimir_insecure_skip_verify: true` exists as an escape hatch only.

The password goes in `/etc/alloy/mimir.password` (`0640 root:alloy`), referenced
by `password_file`, so the rendered config contains no secrets.

## Logs: journald + auditd -> LokiStack

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

Everything below lives in the secrets repo (`secrets_path`) unless noted.

### 1. `mimir_password.yml` — Mimir credentials (metrics)

Vault-encrypted; already present from the grafana_agent era. Included for
`mimir_username`/`mimir_password`; basic auth is only rendered when both are
set. Nothing to do.

### 2. `loki_token.yml` — the push token (logs)

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

### 3. `files/lokistack-ingress-ca.crt` — the cluster ingress CA (in this role)

Both the LokiStack gateway route and the Mimir route are served by the cluster's
self-signed ingress certificate (`CN=*.apps.pok.os.sepia.ceph.com`, issued by
`ingress-operator@...`), so the host CA bundle will not verify them. Extract the
CA once:

```bash
oc get cm -n openshift-config-managed default-ingress-cert \
  -o jsonpath='{.data.ca-bundle\.crt}' \
  > roles/alloy/files/lokistack-ingress-ca.crt
```

> **This expires.** When the ingress certificate rotates, every host stops
> shipping **both metrics and logs** at once and does so quietly — the failure
> shows up in `journalctl -u alloy`, not anywhere you'd normally look.
> Re-extract and re-run the play when that happens.

We deliberately do *not* use `insecure_skip_verify` for either endpoint. That
was tolerable for metrics alone; it isn't for the transport carrying an audit
trail, and once the CA is on the host there's no reason to skip it for Mimir.

### 4. Per-group `alloy_extra_log_paths` (optional)

```yaml
# ceph-sepia-secrets/ansible/inventory/group_vars/public_facing.yml
alloy_extra_log_paths:
  - /var/log/nginx/*.log
  - /var/log/apache2/*.log
```

## Role variables

| Variable | Default | Description |
| --- | --- | --- |
| `alloy_metrics_enabled` | `true` | node_exporter -> Mimir |
| `alloy_logs_enabled` | `true` | journald/auditd -> LokiStack |
| `alloy_listen_addr` | `127.0.0.1:12346` | Alloy's HTTP server. **Not** the default 12345 — see below. |
| `alloy_manage_node_exporter` | `true` | Install/start the distro node_exporter (auto-skipped when something else already owns `:9100`) |
| `alloy_node_exporter_address` | `localhost:9100` | What Alloy scrapes |
| `alloy_node_job` | `node` | `job` label |
| `alloy_node_instance` | `<inventory_hostname>:9100` | `instance` label — see the label contract above before changing |
| `alloy_node_nodename` | `<inventory_hostname>` | `nodename` label |
| `alloy_node_scrape_interval` | `60s` | |
| `alloy_mimir_url` | `{{ agent_mimir_url }}` | remote_write URL (from secrets) |
| `alloy_mimir_ca_file` | ingress CA when the URL is under `.apps.pok.os.sepia.ceph.com`, else empty (system bundle) | |
| `alloy_mimir_insecure_skip_verify` | `false` | Escape hatch only |
| `alloy_lokistack_host` | `logging-loki-openshift-logging.apps.pok.os.sepia.ceph.com` | Gateway route |
| `alloy_tenant` | `infrastructure` | LokiStack tenant. Part of the URL path, not a header. |
| `alloy_journal_max_age` | `12h` | Cold-start backlog limit |
| `alloy_collect_auditd` | `true` | Auto-skipped on hosts without auditd |
| `alloy_extra_log_paths` | `[]` | Allowlist of extra globs to tail |
| `alloy_log_level` | `warn` | Alloy's own log level |

## Things this role has to work around

**Port 12345 during the cutover.** Alloy and grafana-agent both default their
HTTP server to `127.0.0.1:12345`, and Debian starts a service the moment its
package is installed. On a host still running grafana-agent, an Alloy on 12345
would fail to bind and crash-loop until the removal tasks and the config handler
caught up. The role sets `CUSTOM_ARGS` in `/etc/default/alloy` (Debian) or
`/etc/sysconfig/alloy` (RHEL) to put Alloy on 12346 and sidestep that window.

**Order of operations.** grafana-agent is removed *before* Alloy is started.
Both would push the same series under identical labels, and Mimir would reject
one side's samples as out-of-order for as long as they overlapped.

**SELinux and `useradd`.** The alloy RPM's `%post` runs
`useradd -r -m -d /var/lib/alloy`, and useradd copying `/etc/skel` into a
`var_lib_t` directory is denied under the targeted policy. The
`customuseradd` module (`files/customuseradd.te`, `tasks/useradd-selinux.yml`)
allows it; it came from the grafana_agent role, whose RPM did the same thing.
Loaded before the package install on RedHat-family hosts; skipped if already
present. Alloy's RPM ships no SELinux policy of its own, so it runs as
`unconfined_service_t`, which can generally read `auditd_log_t`. Check for
denials with `ausearch -m avc -ts recent` on one RHEL host before rolling wide.

**Journal access.** The `alloy` user is added to `systemd-journal` (full journal
rather than just its own entries), and to `adm` on Debian/Ubuntu for
group-readable files under `/var/log`.

**auditd access.** `/var/log/audit/audit.log` is `0600 root:root` inside a `0700`
directory, so group membership alone can't reach it. The role sets
`log_group = alloy` in `/etc/audit/auditd.conf`, which makes auditd itself relax
the file to `0640 root:alloy` and the directory to `0750` — and, unlike a manual
`chmod`, that survives log rotation. auditd is then restarted via `service auditd
restart`, because it refuses `systemctl restart` on RHEL.

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
RHCOS nodes, which cluster monitoring and the in-cluster ClusterLogForwarder
already cover. Testnodes are not in any of these groups; the `testnode` role
can pull this role in for metrics only with `run_alloy_role: true`.

## Verifying

On the host:

```bash
systemctl status alloy                 # active; grafana-agent gone
systemctl status grafana-agent         # Unit grafana-agent.service could not be found
ss -lntp | grep -E '12346|9100'        # alloy and node_exporter
journalctl -u alloy -n 50              # no permission-denied, no 401/403
curl -s localhost:9100/metrics | grep node_uname_info
```

In Grafana (`https://ci-metrics.ceph.com`), the host should appear in the
**Node Exporter Full** dashboard's `$node` dropdown within a couple of minutes,
with its Mimir datasource selected. Or straight against Mimir:

```promql
node_uname_info{job="node", instance="store01.front.sepia.ceph.com:9100"}
count(node_uname_info{job="node"})           # should climb toward 205 as you roll out
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

`journalctl -u alloy | grep -E 'sending batch|remote_write'` gives the real
reason a push failed, and the status code says which layer is at fault:

| Status | Meaning |
| --- | --- |
| `401` / `403` | Token wrong, expired, or missing the tenant ClusterRole (Loki); bad basic auth (Mimir). |
| x509 / TLS error | `files/lokistack-ingress-ca.crt` is stale — the cluster ingress cert rotated. Re-extract it. Affects metrics and logs together. |
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

The `secrets` role, which provides `secrets_path`, and the `community.general`
collection (`listen_ports_facts`).
