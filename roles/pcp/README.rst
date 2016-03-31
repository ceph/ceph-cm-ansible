PCP
===
This role is used to configure a node to run PCP_.

These distros should be fully supported:

- CentOS 7
- Ubuntu 14.04 (Trusty)

These distros are supported as ``pcp_collector`` nodes:

- CentOS 6
- Debian 8
- Fedora 22 (Only via ansible 2)

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

To tell a ``pcp_manager`` host to use a larger timeout when attempting to
connect to hosts that it monitors (in seconds)::

    pmcd_connect_timeout: 1

To tell a ``pcp_manager`` host to run PCP's various web UIs::

    pcp_web: true
