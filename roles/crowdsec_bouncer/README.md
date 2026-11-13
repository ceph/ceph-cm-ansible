# crowdsec_bouncer

Installs the CrowdSec firewall bouncer (`crowdsec-firewall-bouncer-nftables`)
on a host and points it at the lab's CrowdSec Local API (LAPI). Every
`update_frequency` (10s) it pulls the current ban decisions and keeps them in
an nftables set that an `input`/`forward` drop rule consults, in its own
`crowdsec` / `crowdsec6` tables hooked at priority -10 so a ban wins over
ufw's or firewalld's accept rules.

Detection does not happen on the host. The LAPI is the CrowdSec deployment in
the pok OpenShift cluster (`ceph/sepia-openshift`, `security/crowdsec/`),
which reads every `public_facing` host's nginx access logs and sshd journal
out of Loki (shipped by the `alloy` role) and runs the hub's HTTP and sshd
scenarios on them. This role is the remediation half: it turns the LAPI's
4h ban decisions into dropped packets on each host.

`public_facing.yml` runs it on the `public_facing` group after the
`public_facing` role (`--tags crowdsec` for just this role).

## Reaching the LAPI

The LAPI Route (`crowdsec-lapi-jenkins-monitoring.apps.pok.os.sepia.ceph.com`)
resolves to a lab-internal VIP that the OVH and AWS hosts cannot reach, so
`crowdsec_lapi_url` defaults to `https://crowdsec.ceph.com/`, a site on the
soko01 reverse proxy (`reverse_proxy_site_catalog.crowdsec-lapi` in
`roles/public_facing`) that proxies the bouncer endpoints only. In-lab hosts
(soko01 itself) use the Route directly:

```yaml
crowdsec_lapi_url: "https://crowdsec-lapi-jenkins-monitoring.apps.pok.os.sepia.ceph.com/"
# the Route is served with the cluster's ingress certificate
crowdsec_lapi_ca_cert_src: openshift-ingress-ca.pem
```

## Registering a host

Each bouncer has its own API key, created on the LAPI and shown once:

```bash
oc -n jenkins-monitoring exec deploy/crowdsec -- cscli bouncers add <inventory_hostname>-firewall
```

Add it to the `crowdsec_bouncer_api_keys` dict (keyed by inventory
hostname) in the vault-encrypted `ansible/secrets/crowdsec_bouncers.yml` of
`ceph-sepia-secrets`; the role reads that file from `secrets_path` like the
alloy role reads its tokens. The role fails on a host without a key; set
`crowdsec_bouncer_enabled: false` to skip a host instead.
`cscli bouncers list` on the LAPI shows each bouncer's last pull, which is the
health check.

## Variables

See `defaults/main.yml`. The ones worth changing per host:

- `crowdsec_bouncer_enabled` (true): run the role on this host.
- `crowdsec_lapi_url`, `crowdsec_lapi_ca_cert_src`: above.
- `crowdsec_bouncer_api_keys`: secret, vault file in the secrets repo.
- `crowdsec_bouncer_mode` (nftables): `iptables` (ipset + INPUT rule) for a
  host on the legacy backend.
- `crowdsec_bouncer_deny_log` (false): log every dropped packet.
- `crowdsec_bouncer_metrics_enabled` (false): Prometheus metrics on
  `127.0.0.1:60601`; nothing scrapes them yet.

## On the host

```bash
systemctl status crowdsec-firewall-bouncer
tail /var/log/crowdsec-firewall-bouncer.log
nft list set ip crowdsec crowdsec-blacklists      # what is banned right now
```

Decisions themselves live on the LAPI: `cscli decisions list`, and
`cscli decisions delete --ip <addr>` lifts a ban everywhere within one pull.
Addresses that must never be banned go in the `sepia/whitelist` parser in
`security/crowdsec/crowdsec.yaml`, not on the hosts.
