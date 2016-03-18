PCP
===
This role is used to configure a node to run PCP_.

It has been tested on:

- CentOS 7
- Ubuntu 14.04 (Trusty)

.. _PCP: https://github.com/performancecopilot/pcp

Variables
+++++++++

Defaults for these variables are defined in ``roles/pcp/defaults/main.yml``.

To tell a given host to collect performance data::

    pcp_collector: true

To tell the host to aggregate data from other systems::

    pcp_manager: true

To tell a ``pcp_manager`` host to use Avahi to auto-discover other hosts running PCP::

    pcp_use_avahi: true

To tell a ``pcp_manager`` host to probe hosts on its local network for the PCP service::

    pcp_probe: true

To tell a ``pcp_manager`` host to run PCP's various web UIs::

    pcp_web: true
