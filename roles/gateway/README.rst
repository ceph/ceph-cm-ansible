gateway
=======

This role can be used to set up a new OpenVPN gateway for a Ceph test lab 
as well as maintain user access provided a secrets repo is configured.

This role supports CentOS 7.2 only at this time.  It's current intended use
is to maintain the existing OpenVPN gateway in our Sepia_ lab.

It does the following:
- Installs and updates necessary packages
- Maintains user list

Prerequisites
+++++++++++++

- CentOS 7.2

Variables
+++++++++

A list of packages to install that is specific to the role.  These lists are defined in the var files in ``vars/``::

    packages: []

Tags
++++

packages
    Install *and update* packages

users
    Update OpenVPN users list

To Do
+++++

- Support installation of new OpenVPN gateway from scratch
- Upload and maintain CA, keys, and certificates
- Configure networking
- Configure firewall
- Configure fail2ban

.. _Sepia: https://ceph.github.io/sepia/
