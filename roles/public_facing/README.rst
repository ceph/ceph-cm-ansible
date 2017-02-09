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
Override these in your ansible inventory ``host_vars`` file.

``use_ufw: false`` specifies whether an Ubuntu host should use UFW_

host_vars
---------
If required, define these in your ansible inventory ``host_vars`` file.

``ufw_allowed_ports: []`` should be a list of ports you want UFW to allow traffic through.  Port numbers must be double-quoted due to the way the task processes stdout of ``ufw status``.  Example::

    ufw_allowed_ports:
      - "22"
      - "80"
      - "443"

Common Tasks
++++++++++++

UFW
---
At the time of this writing, we only have one public-facing host that doesn't run Ubuntu -- the nameserver.  Its firewall is managed in the ``nameserver`` role.

Despite having network port ACLs defined for each host in our cloud provider's interface, enabling a firewall local to the system will allow us to block abusive IPs using fail2ban_.


.. _UFW: https://wiki.ubuntu.com/UncomplicatedFirewall
.. _fail2ban: http://www.fail2ban.org/wiki/index.php/Main_Page
