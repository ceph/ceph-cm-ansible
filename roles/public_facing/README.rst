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

``download_rsync_egress_limit: "20mbit"`` caps rsyncd (tcp/873) egress on download.ceph.com using ``tc``.

``download_throttled_subnets: []`` is a list of IPv4/IPv6 CIDRs that are allowed but throttled on download.ceph.com.  ``download_throttled_subnets_egress_limit: "50mbit"`` is their aggregate ``tc`` cap.  ``download_throttle_conn_per_ip: 2``, ``download_throttle_req_per_sec: 5``, ``download_throttle_req_burst: 20`` and ``download_throttle_rate_per_conn: "2m"`` are the per-source-IP nginx limits.  See `download.ceph.com`_ below.

``download_public_iface`` is the interface ``tc`` shapes.  Defaults to the interface holding the default IPv4 route.

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

- ``/usr/local/sbin/egress-shaper.sh`` (``egress-shaper.service``) builds an HTB tree on ``download_public_iface``: one class for rsyncd, one aggregate class for ``download_throttled_subnets``, everything else unshaped.
- ``/etc/nginx/conf.d/throttle.conf`` limits connections, request rate and per-connection rate for each source IP in ``download_throttled_subnets``.  All directives are at ``http`` level and keyed on an empty string for everyone else, so other clients are not limited and the vhost (which this role does not manage) needs no changes.

A bandwidth cap alone is not enough: the data volume is IOPS-limited, so hundreds of slow connections can stall nginx even when the pipe is not full.  To block a client outright instead, use ``ufw deny from <cidr>``.

To-Do
+++++

status.sepia.ceph.com
---------------------

 - Install and update Cachet_?

.. _UFW: https://wiki.ubuntu.com/UncomplicatedFirewall
.. _fail2ban: http://www.fail2ban.org/wiki/index.php/Main_Page
.. _Cachet: https://cachethq.io
