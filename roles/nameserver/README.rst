nameserver
==========

This role is used to set up and configure a very basic **internal** BIND DNS server.

This role has only been tested on CentOS 7.2 using BIND9.

It does the following:

- Installs and updates necessary packages
- Enables and configures firewalld
- Manages named.conf and BIND daemon config
- Manages forward and reverse DNS records

Prerequisites
+++++++++++++

- CentOS 7.2

Variables
+++++++++
Most variables are defined in ``roles/nameserver/defaults/main.yml`` and values are chosen to support our Sepia_ lab.  They can be overridden in the ``secrets`` repo.

+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|Variable                                                |Description                                                                                                                |
+========================================================+===========================================================================================================================+
|``packages: []``                                        |A list of packages to install that is specific to the role.  The list is defined in ``roles/nameserver/vars/packages.yml`` |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_dir: "/var/named"``                        |BIND main configuration directory.  Defined in ``roles/nameserver/defaults/main.yml``                                      |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_file: "/etc/named.conf"``                  |BIND main configuration file.  This is the default CentOS path.  Defined in ``roles/nameserver/defaults/main.yml``         |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_data_dir: "/var/named/data"``              |BIND data directory.  named debug output and statistics are stored here.  Defined in ``roles/nameserver/defaults/main.yml``|
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_listen_port: 53``                          |Port BIND should listen on.  Defined in ``roles/nameserver/defaults/main.yml``                                             |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |                                                                                                                           |
|                                                        |                                                                                                                           |
|  named_conf_listen_iface:                              |Interface(s) BIND should listen on.  This defaults to listen on all IPv4 interfaces Ansible detects for the nameserver.    |
|    - 127.0.0.1                                         |Defined in ``roles/nameserver/defaults/main.yml``                                                                          |
|    - "{{ ansible_all_ipv4_addresses[0] }}"             |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_zones_path: "/var/named/zones"``           |Path to BIND zone files.  Defined in ``roles/nameserver/defaults/main.yml``                                                |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |named daemon options.  Writes to ``/etc/sysconfig/named``.  Defined in ``roles/nameserver/defaults/main.yml``              |
|                                                        |                                                                                                                           |
|  named_conf_daemon_opts: []                            |                                                                                                                           |
|                                                        |                                                                                                                           |
|  # Example for IPv4 support only:                      |                                                                                                                           |
|   named_conf_daemon_opts: "-4"                         |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |Values used to populate corresponding settings in each zone file's SOA record                                              |
|                                                        |Defined in ``roles/nameserver/defaults/main.yml``                                                                          |
|  named_conf_soa_ttl: 3600                              |                                                                                                                           |
|  named_conf_soa_refresh: 3600                          |                                                                                                                           |
|  named_conf_soa_retry: 3600                            |                                                                                                                           |
|  named_conf_soa_expire: 604800                         |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |Desired primary nameserver and admin e-mail for each zone file.  Defined in the secrets repo                               |
|                                                        |                                                                                                                           |
|  named_conf_soa: []                                    |                                                                                                                           |
|                                                        |                                                                                                                           |
|  # Example:                                            |                                                                                                                           |
|  named_conf_soa: "ns1.example.com. admin.example.com." |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_recursion: "no"``                          |Define whether recursion should be allowed or not.  Defaults to "no".  Override in Ansible inventory as a hostvar.         |
|                                                        |                                                                                                                           |
|                                                        |**NOTE:** Setting to "yes" will add ``allow-recursion { any; }``. See To-Do.                                               |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |A list of nameservers BIND should forward external DNS queries to.  This is not required but should be defined in          |
|                                                        |``ansible/inventory/group_vars/nameserver.yml`` if desired.                                                                |
|  named_forwarders:                                     |                                                                                                                           |
|    - 8.8.8.8                                           |                                                                                                                           |
|    - 1.1.1.1                                           |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_slave: true``                              |Will configure the server as a DNS slave if true.  This variable is not required but should be set to true in the hostvars |
|                                                        |if desired.                                                                                                                |
|                                                        |                                                                                                                           |
|                                                        |**NOTE:** You must also set ``named_conf_master`` if ``named_conf_slave`` is true.  See below.                             |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``named_conf_master: "1.2.3.4"``                        |Specifies the master server's IP which zones should be transferred from.  Define in hostvars.                              |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|::                                                      |A list of hosts or subnets you want to allow zone transfers to.  This variable is not required but should be defined in    |
|                                                        |hostvars if you wish.  BIND allows AXFR transfers to anywhere by default.                                                  |
|  named_conf_allow_axfr:                                |                                                                                                                           |
|    - localhost                                         |See http://www.zytrax.com/books/dns/ch7/xfer.html#allow-transfer.                                                          |
|    - 1.2.3.4                                           |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|``ddns_keys: {}``                                       |A dictionary defining each Dynamic DNS zone's authorized key.  See **Dynamic DNS** below.  Defined in an encrypted file in |
|                                                        |the secrets repo                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+

**named_domains: []**

The ``named_domains`` dictionary is the bread and butter of creating zone files.  It is in standard YAML syntax.  Each domain (key) must have ``forward``, ``ipvar``, and ``dynamic`` defined.  ``ipvar`` can be set to ``NULL``.  Optional values include ``miscrecords``, ``reverse``, and ``ddns_hostname_prefixes``.

``forward``
  The domain of the forward lookup zone for each domain (key)

``ipvar`` OR ``ipvars[]``
  The variable(s) assigned to a system in the Ansible inventory.  This allows systems to have multiple IPs assigned for a front and ipmi network, for example.  See **Inventory Example** below.

``dynamic``
  Specifies whether the parent zone/domain should allow Dynamic DNS records.  See **Dynamic DNS** below for more information.

``ddns_hostname_prefixes``
  This should be a list of dynamic hostname prefixes you don't want overwritten if a zone/domain has static and dynamic records.  See **Dynamic DNS** below.

``miscrecords``
  Records to add to corresponding ``forward`` zone file.  This is a good place for CNAMEs and MX records and records for hosts you don't have in your Ansible inventory.  If your main nameserver is in a subdomain, you should create its glue record here.  See example.

``reverse``
  This should be a list of each reverse lookup IP C-Block address corresponding to the domain (key).  See example.

**Example**::

    named_domains:
      example.com:
        ipvar: NULL
        dynamic: false
        forward: example.com
        miscrecords:
          - www                 IN      A       8.8.8.8
          - www                 IN      TXT     "my www host"
          - ns1.private         IN      A       192.168.0.1
      private.example.com:
        ipvars:
          - ip
          - if_25Gb_ip
        dynamic: true
        ddns_hostname_prefixes:
          - dyn
        forward: private.example.com
        miscrecords:
          - mail                IN      MX      192.168.0.2
          - email               IN      CNAME   mail
        reverse:
          - 192.168.0.0
          - 192.168.1.0
          - 192.168.2.0
      mgmt.example.com:
        ipvar: mgmt
        dynamic: false
        forward: mgmt.example.com
        reverse:
          - 192.168.10.0
          - 192.168.11.0
          - 192.168.12.0
      ddns.example.com:
        ipvar: NULL
        dynamic: true
        forward: ddns.example.com
        
Inventory
+++++++++
This role will create forward and reverse DNS records for any host defined in your Ansible inventory when given an IP address assigned to a variable matching ``ipvar`` in ``named_domains``.

Using the ``named_domains`` example above and inventory below, forward *and reverse* records for ``ns1.private.example.com``, ``tester050.private.example.com``, and ``tester050.mgmt.example.com`` would be created.

**Example**::

    [nameserver]
    ns1.private.example.com ip=192.168.0.1

    [testnodes]
    tester050.private.example.com ip=192.168.1.50 mgmt=192.168.11.50

**Note:** Hosts in inventory with no IP address defined will not have records created and should be added to ``miscrecords`` in ``named_domains``.

Dynamic DNS
+++++++++++
If you wish to use the Dynamic DNS feature of this role, you should generate an HMAC-MD5 keypair using dnssec-keygen_ for each zone you want to be able to dynamically update.  The key generated should be pasted in the ``secret`` value of the ``ddns_keys`` dictionary for the corresponding domain.

**Example**::

    $ dnssec-keygen -a HMAC-MD5 -b 512 -n USER ddns.example.com
    Kddns.example.com.+157+57501
    $ cat Kddns.example.com.+157+57501.key
    ddns.example.com. IN KEY 0 3 157 LxFSAiBgKYtsTTV/hjaK7LNdsbk19xQv0ZY9xLtrpdIWhf2S4gurD5GJ JjP9N8bnlCPKc7zVy+JcBYbSMSsm2A==

    # In {{ secrets_path }}/nameserver.yml
    ---
    ddns_keys:
      ddns.example.com:
        secret: "LxFSAiBgKYtsTTV/hjaK7LNdsbk19xQv0ZY9xLtrpdIWhf2S4gurD5GJ JjP9N8bnlCPKc7zVy+JcBYbSMSsm2A=="

``roles/nameserver/templates/named.conf.j2`` loops through each domain in ``named_domains``, checks whether ``dynamic: true`` and if so, then loops through ``ddns_keys`` and matches the secret key to the domain.

These instructions assume you'll either have one host updating DNS records or you'll be sharing the resulting key.  Clients can use nsupdate_ to update the nameserver.  Configuring that is outside the scope of this role.

You can have two types of Dynamic DNS zones:

  1. A pure dynamic DNS zone with no static A records
  2. A mixed zone consisting of both dynamic and static records

For a mixed zone, you must specify ``ddns_hostname_prefixes`` under the domain in ``named_domains`` else your dynamic records will be overwritten each time the records task is run.  **Example**::

    named_domains:
      private.example.com:
        forward: private.example.com
        ipvar: ip
        dynamic: true
        ddns_hostname_prefixes:
          - foo
      ddns.example.com:
        forward: ddns.example.com
        ipvar: NULL
        dynamic: true

In the example above, a dynamic hostname of ``foo001.private.example.com`` will be saved and restored at the end of the records task.  If you *dynamically* added a hostname of ``bar001.private.example.com`` however, the records task will remove it.  Do not create static hostnames in your ansible inventory using any of the prefixes in ``ddns_hostname_prefixes`` or you'll end up with duplicates in the zone file.

The records task will not modify the ddns.example.com zone file.

For our upstream test lab's purposes, this allows us to combine static and dynamic records in our ``front.sepia.ceph.com`` domain so teuthology_'s ``lab_domain`` variable can remain unchanged.

This role also configures DNS slaves to accept DDNS updates and will forward them to the master using the ``allow-update-forwarding`` parameter in ``/etc/named.conf``.  This is particularly useful in our Sepia lab since our master server can't send ``NOTIFY`` messages directly to the slave.

**NOTE:** Reverse zone Dynamic DNS is not supported at this time.

Tags
++++

packages
    Install *and update* packages

config
    Configure and restart named service (if config changes)

firewall
    Enable firewalld and allow dns traffic

records
    Compiles and writes forward and reverse zone files using ``named_domains`` and Ansible inventory

Dependencies
++++++++++++

This role depends on the following roles:

secrets
    Provides a var, ``secrets_path``, containing the path of the secrets repository, a tree of Ansible variable files.

sudo
    Sets ``ansible_sudo: true`` for this role which causes all the plays in this role to execute with sudo.

To-Do
+++++

- Allow additional user-defined firewall rules
- DNSSEC
- Add support for specifying networks to allow recursion from

.. _Sepia: https://ceph.github.io/sepia/
.. _dnssec-keygen: https://ftp.isc.org/isc/bind9/cur/9.9/doc/arm/man.dnssec-keygen.html
.. _nsupdate: https://linux.die.net/man/8/nsupdate
.. _teuthology: http://docs.ceph.com/teuthology/docs/siteconfig.html?highlight=lab_domain
