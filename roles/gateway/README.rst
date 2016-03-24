gateway
=======

This role can be used to set up a new OpenVPN gateway for a Ceph test lab 
as well as maintain user access provided a secrets repo is configured.

This role supports CentOS 7.2 only at this time.  Its current intended use
is to maintain the existing OpenVPN gateway in our Sepia_ lab.

It does the following:
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

Tags
++++

packages
    Install *and update* packages

users
    Update OpenVPN users list

Dependencies
++++++++++++

This role depends on the following roles:

secrets
    Provides a var, ``secrets_path``, containing the path of the secrets repository, a tree of ansible variable files.

To Do
+++++

- Support installation of new OpenVPN gateway from scratch
- Generate and pull (to secrets?) CA, keys, and certificates
- Configure networking
- Configure firewall
- Configure fail2ban
- Configure log rotation

.. _Sepia: https://ceph.github.io/sepia/
