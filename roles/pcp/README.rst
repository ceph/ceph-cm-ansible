PCP
===
This role is used to configure a node to run PCP_.

PCP's main function is to collect performance-related metrics. By default, this
role will set up each node as a ``pcp_collector``. It is also capable of
installing and configuring the necessary packages to act as a ``pcp_manager``,
collecting data from all the ``pcp_collector`` nodes; and also as a ``pcp_web``
host, providing various web UIs to display the data graphically.

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

To use upstream-provided packages instead of the distro's packages, set::

    upstream_repo: true

To tell a given host to collect performance data using ``pmcd``, and to run
``pmlogger`` to create archive logs::

    pcp_collector: true

To tell the host to aggregate data from other systems using ``pmmgr`` and
corresponding ``pmlogger`` processes for each ``pcp_collector`` node::

    pcp_manager: true

To tell a ``pcp_manager`` host to use Avahi to auto-discover other hosts running PCP::

    pcp_use_avahi: true

To tell a ``pcp_manager`` host to probe hosts on its local network for the PCP service::

    pcp_probe: true

To tell a ``pcp_manager`` host to use a larger timeout when attempting to
connect to hosts that it monitors (in seconds)::

    pmcd_connect_timeout: 1

To tell a ``pcp_manager`` host to retain full-resolution archives for a year
(format is a `PCP time window`_)::

    pmlogmerge_retain: "365days"

To tell a ``pcp_manager`` host to run PCP's various web UIs::

    pcp_web: true


.. _PCP time window: http://www.pcp.io/books/PCP_UAG/html/LE14729-PARENT.html
