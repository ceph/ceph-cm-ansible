ntp-server
==========

This role is used to set up and configure an NTP server on RHEL or CentOS 7 using NTPd or Chronyd.

Notes
+++++

Virtual machines should not be used as NTP servers.

Red Hat best practices were followed: https://access.redhat.com/solutions/778603

Variables
+++++++++

+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
|Variable                                                |Description                                                                                                                |
+========================================================+===========================================================================================================================+
|::                                                      |A list of LANs that are permitted to query the NTP server running on the host.                                             |
|                                                        |                                                                                                                           |
|  ntp_permitted_lans:                                   |                                                                                                                           |
|    - 192.168.0.0/24                                    |Must be in CIDR format as shown.                                                                                           |
|    - 172.20.20.0/20                                    |                                                                                                                           |
|                                                        |                                                                                                                           |
+--------------------------------------------------------+---------------------------------------------------------------------------------------------------------------------------+
