Common
======

The common role consists of tasks we want run on all hosts in the Ansible
inventory (i.e., not just testnodes).  This includes things like setting the
timezone and enabling repos.

Usage
+++++

The common role is run on every host in the Ansible inventory and is typically
called by another role's playbook.  Calling it manually to run a
specific task (such as setting the timezone) can be done like so::

    ansible-playbook common.yml --limit="host.example.com" --tags="timezone"

**WARNING:** If the common role is run without a valid tag, the full role will run.  See ``roles/common/tasks`` for what this includes.

Variables
+++++++++

``timezone`` is the desired timezone for all hosts in the Ansible inventory.
Defined in ``roles/common/defaults/main.yml``.  Values in the TZ column here_ can be used
in place of the default value.

``subscription_manager_activationkey`` and ``subscription_manager_org`` are used
to register systems with Red Hat's Subscription Manager tool.  Blank defaults
are set in ``roles/common/defaults/main.yml`` and should be overridden in the
secrets repo.

``rhsm_repos`` is a list of Red Hat repos that a system should subscribe to.  We
have them defined in ``roles/common/vars/redhat_{6,7}.yml``.

``use_satellite`` is a boolean that sets whether a local Red Hat Satellite server is available and should be used instead of Red Hat's CDN.  If ``use_satellite`` is set to true, you must also define ``subscription_manager_activationkey``, ``subscription_manager_org``, and ``satellite_cert_rpm`` in your secrets repo.  ``set_rhsm_release: true`` will add ``--release=X.Y`` to the ``subscription-manager register`` command; This prevents a RHEL7.6 install from being upgraded to RHEL7.7, for example.::

    # Red Hat Satellite vars
    use_satellite: true
    satellite_cert_rpm: "http://satellite.example.com/pub/katello-ca-consumer-latest.noarch.rpm"
    subscription_manager_org: "Your Org"
    subscription_manager_activationkey: "abc123"
    set_rhsm_release: false

``epel_mirror_baseurl`` is self explanatory and defined in
``roles/common/defaults/main.yml``.  Can be overwritten in secrets if you run
your own local epel mirror.

``epel_repos`` is a dictionary used to create epel repo files.  Defined in ``roles/common/defaults/main.yml``.

``enable_epel`` is a boolean that sets whether epel repos should be enabled.
Defined in ``roles/common/defaults/main.yml``.

``beta_repos`` is a dict of internal Red Hat beta repos used to create repo files in /etc/yum.repos.d.  We have these defined in the secrets repo.  See ``epel_repos`` for dict syntax.

``yum_timeout`` is an integer used to set the yum timeout.  Defined in
``roles/common/defaults/main.yml``.

``nagios_allowed_hosts`` should be a comma-separated list of hosts allowed to query NRPE.  Override in the secrets repo.

The following variables are used to configure NRPE_ (Nagios Remote Plugin
Executor) on hosts in ``/etc/nagios/nrpe.cfg``.  The system defaults differ between distros (``nrpe`` in
RHEL vs ``nagios-nrpe-server`` in Ubuntu).  Setting these allows us to make
tasks OS-agnostic.  They variables are mostly self-explanatory and defined in
``roles/common/vars/{yum,apt}_systems.yml``::

    ## Ubuntu variables are used in this example

    # Used to install the package and start/stop the service
    nrpe_service_name: nagios-nrpe-server

    # NRPE service runs as this user/group
    nrpe_user: nagios
    nrpe_group: nagios

    # Where nagios plugins can be found
    nagios_plugins_directory: /usr/lib/nagios/plugins

    # List of packages needed for NRPE use
    nrpe_packages:
      - nagios-nrpe-server
      - nagios-plugins-basic

Definining ``secondary_nic_mac`` as a hostvar will configure the corresponding NIC to use DHCP.  This 
assumes you've configured a static IP definition on your DHCP server and the NIC is cabled.
The tasks will automatically set the MTU to 9000 if the NIC is 10Gb or 25Gb. Override in ``groups_vars/group.yml`` as ``secondary_nic_mtu=1500``
This taskset only supports one secondary NIC.::

    secondary_nic_mac: 'DE:AD:BE:EF:00:11'

Tags
++++

timezone
    Sets the timezone

monitoring-scripts
    Installs smartmontools (if necessary) and uploads custom monitoring scripts.
    See ``roles/common/tasks/disk_monitoring.yml``.

entitlements
    Registers a Red Hat host then subscribes and enables repos.  See
    ``roles/common/tasks/rhel-entitlements.yml``.

kerberos
    Configures kerberos.  See ``roles/common/tasks/kerberos.yml``.

nagios
    Installs and configures nrpe service (including firewalld and SELinux if
    applicable).  ``monitoring-scripts`` is also always run with this tag since
    NRPE isn't very useful without them.

secondary-nic
    Configure secondary NIC if ``secondary_nic_mac`` is defined.

To Do
+++++

- Rewrite ``roles/common/tasks/rhel-entitlements.yml`` to use Ansible's
  redhat_subscription_module_.

.. _here: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
.. _NRPE: https://github.com/NagiosEnterprises/nrpe
.. _redhat_subscription_module: https://docs.ansible.com/ansible/redhat_subscription_module.html
