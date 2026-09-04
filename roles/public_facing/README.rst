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

Things the playbook does NOT manage:

- **Let's Encrypt certs.**  certbot is installed as a snap along with the
  ``certbot-dns-nsone`` plugin, and ``snap.certbot.renew.timer`` keeps
  existing certs renewed.  Issuing a cert for a new site is a one-time manual
  step, e.g.::

    sudo certbot certonly --authenticator dns-nsone \
      --dns-nsone-credentials /etc/letsencrypt/nsone.ini \
      --dns-nsone-propagation-seconds 60 -d newsite.ceph.com -n

- ``/etc/letsencrypt/nsone.ini`` (NS1 API key for DNS-01 challenges) is left
  in place on the host; it is not templated by ansible.
- The nginx ``default`` site (serves iPXE bits on the lab-internal IP) and
  the disabled ``teuthology-api.conf``.

Adding a new proxied site: add a catalog entry to ``defaults/main.yml``, a
matching template under ``templates/reverse_proxy/sites/``, an entry in the
host's ``reverse_proxy_sites`` plus a new key in ``anubis_ed25519_keys``
(both in ceph-sepia-secrets host_vars), issue the cert (above), then run the
role with ``--tags reverse_proxy``.

To-Do
+++++

status.sepia.ceph.com
---------------------

 - Install and update Cachet_?

.. _Anubis: https://anubis.techaro.lol
.. _UFW: https://wiki.ubuntu.com/UncomplicatedFirewall
.. _fail2ban: http://www.fail2ban.org/wiki/index.php/Main_Page
.. _Cachet: https://cachethq.io
