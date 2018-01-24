fog-server
==========

This role can be used to install and update a FOG_ server.  It has been minimally tested on Ubuntu 16.04 and CentOS 7.4.

Notes
+++++

* You must manually configure firewall, SELinux, and repos on RHEL/CentOS/Fedora.
* This role assumes the ``sudo`` group already exists and has passwordless sudo access.
* We'd recommend running in verbose mode to see shell output.  It can take around 10 minutes for the Install and Update tasks to complete.

Variables
+++++++++

+-----------------------------------------------------------------------------------------------------------------------------------------------+
| **Required Variables**                                                                                                                        |
+----------------------------+------------------------------------------------------------------------------------------------------------------+
| ``fog_user: fog``          | Name for user account to be created on the system.  The application will be run from this user's home directory. |
+----------------------------+------------------------------------------------------------------------------------------------------------------+
| ``fog_branch: master``     | Branch of FOG to checkout and install.  Defaults to master but could be set to ``working`` for bleeding edge.    |
+----------------------------+------------------------------------------------------------------------------------------------------------------+
| ``fog_dhcp_server: false`` | Set to ``true`` if you want FOG to install and configure the host as a DHCP server.                              |
+----------------------------+------------------------------------------------------------------------------------------------------------------+

**Optional Variables**

If none of these are set, the FOG defaults will be used.  For simplicity's sake, the variables have been named after the variables in fogsettings_.  Read the official documentation for a description of what each does.

* fog_ipaddress
* fog_interface
* fog_submask
* fog_routeraddress
* fog_plainrouter
* fog_dnsaddress
* fog_password
* fog_startrange (Required if ``fog_dhcp_server: true``)
* fog_endrange (Required if ``fog_dhcp_server: true``)
* fog_snmysqluser
* fog_snmysqlpass
* fog_snmysqlhost
* fog_images_path
* fog_docroot
* fog_webroot
* fog_httpproto

.. _FOG: https://fogproject.org/
.. _fogsettings: https://wiki.fogproject.org/wiki/index.php?title=.fogsettings
