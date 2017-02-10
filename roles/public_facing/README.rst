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

    # Note: sshd_logpath gets defined automatically in roles/public_facing/tasks/fail2ban.yml

host_vars
---------
If required, define these in your ansible inventory ``host_vars`` file.

``ufw_allowed_ports: []`` should be a list of ports you want UFW to allow traffic through.  Port numbers must be double-quoted due to the way the task processes stdout of ``ufw status``.  Example::

    ufw_allowed_ports:
      - "22"
      - "80"
      - "443"

``f2b_filters: {}`` is a dictionary of additional filters fail2ban should use.  For example, our status portal running Cachet has an additional fail2ban service monitoring repeated login attempts to the admin portal.  See filter example::

    f2b_filters:
      apache-cachet:
      failregex: "<HOST> .*GET /auth/login.*$"

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


.. _UFW: https://wiki.ubuntu.com/UncomplicatedFirewall
.. _fail2ban: http://www.fail2ban.org/wiki/index.php/Main_Page
