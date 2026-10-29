public_facing
=============

This role is used to manage the various public-facing hosts we have.  Each host has various configs not managed by the ``common`` role.  This playbook aims to:

- Provide automation in the event of disaster recovery
- Automate repeatable tasks
- Automate 'one-off' host or service nuances

Usage
+++++

Example::

  ansible-playbook public_facing.yml --limit="download.ceph.com"

Variables
+++++++++

Defaults
--------
Defined in ``roles/public_facing/defaults/main.yml``  Override these in the ansible inventory ``host_vars`` file.

``use_ufw: false`` specifies whether an Ubuntu host should use UFW_

``f2b_ignoreip: "127.0.0.1"``
``f2b_bantime: "43200"``
``f2b_findtime: "900"``
``f2b_maxretry: 5``

``use_fail2ban: true`` specifies whether a host should use fail2ban_

``f2b_services: {}`` is a dictionary listing services fail2ban should monitor.  See example below::

    f2b_services:
      sshd:
        enabled: "true"
        port: "22"
        maxretry: 3
        findtime: "3600" # 1hr
        filter: "sshd"
        logpath: "{{ sshd_logpath }}"
      sshd-ddos:
        enabled: "true"
        port: "22"
        maxretry: 3
        filter: "sshd-ddos"
        logpath: "{{ sshd_logpath }}"
        bantime: -1 # optionally set in host_vars

    # Note: sshd_logpath gets defined automatically in roles/public_facing/tasks/fail2ban.yml

``download_rsync_egress_limit: "200mbit"`` caps rsyncd (tcp/873) egress on download.ceph.com using ``tc``.  Don't set it too low: slow syncs pile up and exhaust rsyncd's connection slots.

``download_rsync_max_connections: 128`` and ``download_rsync_timeout: 1800`` are rsyncd's global connection limit and idle timeout (seconds); the timeout reaps wedged mirror sessions that would otherwise hold slots indefinitely.

``download_throttled_subnets: []`` is a list of IPv4/IPv6 CIDRs that are allowed but throttled on download.ceph.com.  ``download_throttled_subnets_egress_limit: "50mbit"`` is their aggregate ``tc`` cap.  ``download_throttle_conn_per_ip: 2``, ``download_throttle_req_per_sec: 5``, ``download_throttle_req_burst: 20`` and ``download_throttle_rate_per_conn: "2m"`` are the per-source-IP nginx limits.  See `download.ceph.com`_ below.

``download_public_iface`` is the interface ``tc`` shapes.  Defaults to the interface holding the default IPv4 route.

``download_egress_rate: "1gbit"`` is the instance's actual public bandwidth, used for the root HTB class so the shaper models the real bottleneck.  Update it if the flavor or OVH cap changes.

host_vars
---------
If required, define these in your ansible inventory ``host_vars`` file.

``ufw_allowed_ports: []`` should be a list of ports you want UFW to allow traffic through.  You may optionally defined a ``source_ip`` by adding ``:1.2.3.4`` after the port.  List items must be double-quoted due to the way the task processes stdout of ``ufw status``.  Example::

    ufw_allowed_ports:
      - "22"
      - "80"
      - "443"
      - "3306:1.2.3.4"

``f2b_filters: {}`` is a dictionary of additional filters fail2ban should use.  For example, our status portal running Cachet has an additional fail2ban service monitoring repeated login attempts to the admin portal.  ``maxlines`` is an optional variable.  See filter example::

    f2b_filters:
      apache-cachet:
        failregex: "<HOST> .*GET /auth/login.*$"
      example-filter:
        failregex: "<HOST> .*foo$"
        maxlines: 3

Common Tasks
++++++++++++

These are tasks that are applicable to all our public-facing hosts.

UFW
---
At the time of this writing, we only have one public-facing host that doesn't run Ubuntu -- the nameserver.  Its firewall is managed in the ``nameserver`` role.

Despite having network port ACLs defined for each host in our cloud provider's interface, enabling a firewall local to the system will allow us to block abusive IPs using fail2ban.

fail2ban
--------
If ``use_fail2ban`` is set to ``true`` this role will install, configure, and enable fail2ban.

download.ceph.com
-----------------
The host-specific tasks create the ``signer`` and ``bitergia`` users, install the hourly ``/usr/libexec/make_timestamp`` cron (mirrors use ``/timestamp`` to check freshness), keep the letsencrypt cert renewed, and protect the instance's capped public bandwidth:

- ``/usr/local/sbin/egress-shaper.sh`` (``egress-shaper.service``) builds an HTB tree on ``download_public_iface``, with the root class sized to ``download_egress_rate``: one class for rsyncd, one aggregate class for ``download_throttled_subnets``, everything else limited only by the root class.  The script runs with ``set -eu`` so a failed ``tc`` command fails the (oneshot) unit instead of leaving a half-applied tree.
- ``/etc/rsyncd.conf`` serves the ``[ceph]`` module mirrors sync from.  There is intentionally no restart handler: rsyncd re-reads the config for every new connection, and restarting the daemon would kill in-flight mirror syncs.
- ``/etc/nginx/conf.d/throttle.conf`` limits connections, request rate and per-connection rate for each source IP in ``download_throttled_subnets``.  All directives are at ``http`` level and keyed on an empty string for everyone else, so other clients are not limited and the vhost (which this role does not manage) needs no changes.

A bandwidth cap alone is not enough: the data volume is IOPS-limited, so hundreds of slow connections can stall nginx even when the pipe is not full.  To block a client outright instead, use ``ufw deny from <cidr>``.

Reverse proxies
+++++++++++++++

``tasks/reverse_proxy.yml`` manages the nginx + Anubis_ + certbot reverse
proxy stack.  It was reverse-engineered from the hand-built config on
soko01.front.sepia.ceph.com (2026-09) and only runs on hosts that define
``reverse_proxy_sites`` in inventory host_vars.  Most sites proxy to
OpenShift routes on the pok cluster and sit behind a per-site Anubis
instance (``anubis@<site>.service``) to fend off scraper botnets.

Variables (see ``defaults/main.yml``):

- ``reverse_proxy_site_catalog`` describes every site the role knows how to
  deploy: the config filename in ``/etc/nginx/sites-available``, the upstream
  host, and (if the site is behind Anubis) the local Anubis port, metrics
  port, upstream scheme, and bot policy.  The nginx site templates in
  ``templates/reverse_proxy/sites/`` pull ports/upstreams from the catalog so
  the nginx and Anubis halves can't drift apart.
- ``reverse_proxy_sites`` (host_vars, ceph-sepia-secrets) lists which catalog
  entries to deploy on a host.
- ``anubis_ed25519_keys`` (host_vars, ceph-sepia-secrets) is a dict of
  per-instance ED25519 signing keys (``openssl rand -hex 32``).  These are
  private; never commit them here.
- ``reverse_proxy_internal_ip`` defaults to the inventory ``ip=`` var and is
  used for the nginx resolver and Anubis metrics binds.
- ``reverse_proxy_paddles_readonly_allow`` / ``..._allow_extra`` (the latter
  in host_vars, ceph-sepia-secrets) list the source addresses allowed to use
  the GET-only paddles proxy at ``https://pulpito.ceph.com/_paddles/runs/...``
  (same paths paddles serves under ``/runs/``; 60s cache; bypasses Anubis).
  paddles has no auth of its own, so the location is limited to ``GET``.
  External CI dashboards that only need to read results get an entry here,
  not a WireGuard peer.  The ``href`` fields paddles returns point at the
  internal paddles name; consumers should build URLs from run/job names.
- ``git_ratelimit_exempt_sources`` / ``git_ratelimit_exempt_sources_extra``
  (the latter in host_vars, ceph-sepia-secrets, for personal/third-party
  addresses) / ``git_ratelimit_rate`` / ``git_ratelimit_burst`` control the
  per-IP nginx rate limit on git.ceph.com gitweb (HTML) paths.  Lab sources
  -- including
  ``192.86.31.2``, the border NAT egress every lab host appears as -- are
  exempt, and git smart-HTTP paths (``info/refs``, ``git-upload-pack``,
  ``git-receive-pack``) are never limited, so clones/fetches and CI are
  unaffected anywhere.  Over-budget requests get a 429.  Keep the exempt
  list in sync with the ``lab-and-monitoring`` allowlist in
  ``files/reverse_proxy/botPolicies.yaml``.

Things the playbook does NOT manage:

- **Let's Encrypt certs.**  certbot is installed as a snap along with the
  ``certbot-dns-nsone`` plugin, and ``snap.certbot.renew.timer`` keeps
  existing certs renewed.  Issuing a cert for a new site is a one-time manual
  step, e.g.::

    sudo certbot certonly --authenticator dns-nsone \
      --dns-nsone-credentials /etc/letsencrypt/nsone.ini \
      --dns-nsone-propagation-seconds 60 -d newsite.ceph.com -n

  ``*.sepia.ceph.com`` names are different: the sepia zone lives on
  vpn-pub/soko03 (not NS1), so those certs use ``--authenticator manual``
  with the ``/etc/letsencrypt/hooks/nsone-{auth,cleanup}-sepia.sh`` hooks
  and a ``_acme-challenge.<name>.sepia.ceph.com`` →
  ``_acme-challenge.<name>.ceph.com`` CNAME in the sepia zone
  (ceph-sepia-secrets ``nameserver.yml``).  Never ``--authenticator nginx``
  with dns-01 — it silently never renews (apt-mirror, 2026-08-31).

  After issuing, check that ``/etc/letsencrypt/renewal/<name>.conf`` has
  ``dns_nsone_credentials = /etc/letsencrypt/nsone.ini`` under
  ``authenticator = dns-nsone``.  Without it every renewal fails asking for
  the credentials path (git + pulpito, 2026-09-28).

  The role does install a certbot deploy hook
  (``/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh``) so nginx is
  reloaded after each successful renewal; none of the authenticators above
  have an installer, so without the hook nginx keeps serving the old cert.
- ``/etc/letsencrypt/nsone.ini`` (NS1 API key for DNS-01 challenges) is left
  in place on the host; it is not templated by ansible.
- The nginx ``default`` site (serves iPXE bits on the lab-internal IP) and
  the disabled ``teuthology-api.conf``.

Adding a new proxied site: add a catalog entry to ``defaults/main.yml``, a
matching template under ``templates/reverse_proxy/sites/``, an entry in the
host's ``reverse_proxy_sites`` plus a new key in ``anubis_ed25519_keys``
(both in ceph-sepia-secrets host_vars), issue the cert (above), then run the
role with ``--tags reverse_proxy``.

.. _Anubis: https://anubis.techaro.lol
.. _UFW: https://wiki.ubuntu.com/UncomplicatedFirewall
.. _fail2ban: http://www.fail2ban.org/wiki/index.php/Main_Page
