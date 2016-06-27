gateway
=======

This role can be used to set up a new OpenVPN gateway for a Ceph test lab 
as well as maintain user access provided a secrets repo is configured.

This role supports CentOS 7.2 only at this time.  Its current intended use
is to maintain the existing OpenVPN gateway in our Sepia_ lab.

It does the following:
- Configures network devices
- Configures firewalld
- Configures fail2ban
- Installs and updates necessary packages
- Maintains user list

Prerequisites
+++++++++++++

- CentOS 7.2

Variables
+++++++++

A list of packages to install that is specific to the role.  The list is defined in ``roles/gateway/vars/packages.yml``::

    packages: []

A unique name to give to your OpenVPN service.  This name is used to organize configuration files and start/stop the service.  Defined in the secrets repo::

    openvpn_server_name: []

The directory in which the OpenVPN server CA, keys, certs, and user file should be saved.  Defined in the secrets repo::

    openvpn_data_dir: []

Contains paths, file permission (modes), and data to store and maintain OpenVPN CA, cert, key, and main server config.  Consult your server.conf on what you should define here.  For reference, we have dh1024.pem, server.crt, server.key, tlsauth, and server.conf defined.  Defined in the secrets repo::

    gateway_secrets: []

    # Example:
    gateway_secrets:
      - path: "{{ openvpn_data_dir }}/server.crt"
        mode: 0644
        data: |
          -----BEGIN CERTIFICATE-----
          ...
          -----END CERTIFICATE-----
      - path: /etc/openvpn/server.conf
        mode: 0644
        data: |
          script-security 2
          ...
          cert {{ openvpn_data_dir }}/server.crt

A list of users that don't have their ssh pubkey added to the ``teuthology_user`` authorized_keys but still need VPN access::

    openvpn_users: []

    # Example:
    openvpn_users:
      - ovpn: user@host etc...

The following vars are used to populate ``/etc/resolv.conf``.  Defined in the
secrets repo::

    gw_resolv_search: []
    # Example: gw_resolv_search: "front.example.com"

    gw_resolv_ns: []
    # Example:
    gw_resolv_ns:
      - 1.2.3.4
      - 8.8.8.8

The ``gw_networks`` dictionary assumes you have individual NICs for each
VLAN in your lab.  The subelements ``peerdns`` and ``dns{1,2}`` are optional for
all but one NIC.  These are what set your nameservers in
``/etc/resolv.conf``.
``dns1`` and ``dns2`` should be defined under a single NIC and ``peerdns``
should be set to ``"yes"``.  Defined in the
secrets repo::

    # Example:
    gw_networks:
      private:
        ifname: "eth0"
        mac: "de:ad:be:ef:12:34"
        ip4: "192.168.1.100"
        netmask: "255.255.240.0"
        gw4: "192.168.1.1"
        defroute: "yes"
        peerdns: "yes"
        search "private.example.com"
        dns1: "192.168.1.1"
        dns2: "8.8.8.8"
      public:
        ifname: "eth1"
        etc...

The *fail2ban* vars are explained in /etc/fail2ban/jail.conf.  We've set
defaults in ``roles/gateway/defaults/main.yml`` but they can be overridden in
the secrets repo::

    gw_f2b_ignoreip: "127.0.0.1/8"
    gw_f2b_bantime: "43200"
    gw_f2b_findtime: "600"
    gw_f2b_maxretry: "5"

``gw_f2b_services`` is a dictionary listing services fail2ban should monitor.  Defined in
``roles/gateway/defaults/main.yml``.  See example below::

    gw_f2b_services:
      sshd:
        enabled: "true"
        port: "ssh"
        logpath: "%(sshd_log)s"
      apache:
        enabled: "true"
        port: "http"

Tags
++++

packages
    Install *and update* packages

users
    Update OpenVPN users list

networking
    Configure basic networking (NICs, IP forwarding, resolv.conf)

firewall
    Configure firewalld

**NOTE:** Ansible v2.1 or later is required for the initial firewall setup as the ``masquerade`` parameter is new to that version.

fail2ban
    Configure fail2ban

Dependencies
++++++++++++

This role depends on the following roles:

secrets
    Provides a var, ``secrets_path``, containing the path of the secrets repository, a tree of ansible variable files.

To Do
+++++

- Support installation of new OpenVPN gateway from scratch
- Generate and pull (to secrets?) CA, keys, and certificates

.. _Sepia: https://ceph.github.io/sepia/
