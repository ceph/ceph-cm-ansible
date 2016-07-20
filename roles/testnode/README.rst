Testnode
========

This role is used to configure a node for ceph testing using teuthology_ and ceph-qa-suite_.
It will manage the necessary groups, users and configuration needed for teuthology to connect to and use the node.
It also installs a number of packages needed for tasks in ceph-qa-suite and teuthology.

The following distros are supported:

- RHEL 6.X
- RHEL 7.X
- Centos 6.X
- Centos 7.x
- Fedora 20
- Debian Wheezy
- Ubuntu Precise
- Ubuntu Trusty
- Ubuntu Vivid

**NOTE:** This role was first created as a port of ceph-qa-chef_.

Usage
+++++

The testnode role is primarily used by the ``testnodes.yml`` playbook.  This playbook is run by cobbler during
bare-metal imaging to prepare a node for testing and is also used by teuthology during test runs to ensure the config
is correct before testing.

**NOTE:** ``testnodes.yml`` is limited to run against hosts in the ``testnodes`` group by the ``hosts`` key in the playbook.

Variables
+++++++++

Available variables are listed below, along with default values (see ``roles/testnode/defaults/main.yml``). The ``testnode`` role
also allows for variables to be defined per package type (apt, yum), distro, distro major version and distro version.
These overrides are included by ``tasks/vars.yml`` and the specific var files live in ``vars/``.

The host to use as a package mirror::

    mirror_host: apt-mirror.sepia.ceph.com

The host to use as a github mirror::

    git_mirror_host: git.ceph.com

The host to find package-signing keys on (at https://{{key_host}}/keys/{release,autobuild}.asc)::

    key_host: download.ceph.com

This host is used by teuthology to download ceph packages and will be given higher priority on apt systems::

    gitbuilder_host: gitbuilder.ceph.com

The mirror to download and install ``pip`` from::

    pip_mirror_url: "http://{{ mirror_host }}/pypi/simple"

A hash defining yum repos that would be common across a major version. Each key in the hash represents
the filename of a yum repo created in /etc/yum.repos.d. The key/value pairs as the value for that repo
will be used as the properties for the repo file::

    common_yum_repos: {}

    # An example: 
    common_yum_repos:
      rhel-7-fcgi-ceph:
        name: "RHEL 7 Local fastcgi Repo"
        baseurl: http://gitbuilder.ceph.com/mod_fastcgi-rpm-rhel7-x86_64-basic/ref/master/
        enabled: 1
        gpgcheck: 0
        priority: 2

A hash defining version-specific yum repos. Each key in the hash represents
the filename of a yum repo created in /etc/yum.repos.d. The key/value pairs as the value for that repo
will be used as the properties for the repo file::

    yum_repos: {}
    
    # An example:
    yum_repos:
      fedora-fcgi-ceph:
        name: Fedora Local fastcgi Repo
        baseurl: http://gitbuilder.ceph.com/mod_fastcgi-rpm-fedora20-x86_64-basic/ref/master/
        enabled: 1
        gpgcheck: 0
        priority: 0

A list defining apt repos that would be common across a major version or distro. Each item in the list represents
an apt repo to be added to sources.list::

    common_apt_repos: []

    # An Example:
    common_apt_repos:
      # mod_fastcgi for radosgw
      - "deb http://gitbuilder.ceph.com/libapache-mod-fastcgi-deb-{{ansible_distribution_release}}-x86_64-basic/ref/master/ {{ansible_distribution_release}} main"

A list defining version-specific apt repos. Each item in the list represents an apt repo to be added to sources.list::

    apt_repos: []

A list of packages to install that is specific to a distro version.  These lists are defined in the var files in ``vars/``::

    packages: []

A list of packages to install that are common to a distro or distro version. These lists are defined in the var files in ``vars/``::

    common_packages: []

A list of packages that must be installed from epel. These packages are installed with the epel repo explicitly enabled for any
yum-based distro that provides the list in their var file in ``/vars``::

    epel_packages: []

**NOTE:** A good example of how ``packages`` and ``common_packages`` work together is with Ubuntu. The var file ``roles/testnode/vars/ubuntu.yml`` defines
a number of packages in ``common_packages`` that need to be installed across all versions of ubuntu, while the version-specific files
(for example, ``roles/testnode/vars/ubuntu_14.yml``) define packages in ``packages`` that either have varying names across versions or are only needed
for that specific version. This is the same idea behind the vars that control apt and yum repos as well.

A list of ceph packages to remove. It's safe to add packages to this list that aren't currently installed or don't exist. Both ``apt-get`` and ``yum``
handle this case correctly. This list is defined in ``vars/apt_systems.yml`` and ``vars/yum_systems.yml``::

    ceph_packages_to_remove: []

A list of packages to remove. These lists are defined in the var files in ``vars/``::

    packages_to_remove: []

A list of packages to upgrade. These lists are defined in the vars files in ``vars/``::

    packages_to_upgrade: []

The user that teuthology will use to connect to testnodes. This user will be created by this role and assigned to the appropriate groups.
Even though this variable exists, teuthology is not quite ready to support a configurable user::

    teuthology_user: "ubuntu"

This user is created for use in running xfstests from ceph-qa-suite::

    xfstests_user: "fsgqa"

This will control whether or not rpcbind is started before nfs.  Some distros require this, others don't::

    start_rpcbind: true

Set to true if /etc/fstab must be modified to persist things like mount options, which is useful for long-lived
bare-metal machines, less useful for virtual machines that are re-imaged before each job::

    modify_fstab: true

A list of ntp servers to use::

    ntp_servers:
      - 0.us.pool.ntp.org
      - 1.us.pool.ntp.org
      - 2.us.pool.ntp.org
      - 3.us.pool.ntp.org

The lab domain to use when populating systems in cobbler.  (See ``roles/cobbler_systems/tasks/populate_systems.yml``)
This variable is also used to strip the domain from RHEL and CentOS testnode hostnames
The latter is only done if ``lab_domain`` is defined::

    lab_domain: ''

Tags
++++

Available tags are listed below:

cpan
    Install and configure cpan and Amazon::S3.

gpg-keys
    Install gpg keys on Fedora.    

hostname
    Check and set proper fqdn. See, ``roles/testnode/tasks/set_hostname.yml``.

kernel_logging
    Runs a script that enabled kernel logging to the console on ubuntu.        

nfs
    Install and start nfs.

ntp-client
    Setup ntp.

packages
    Install, update and remove packages.

pip
    Install and configure pip.

pubkeys
    Adds the ssh public keys for the ``teuthology_user``.    

remove-ceph
    Ensure all ceph related packages are removed. See ``packages_to_remove`` in the distros var file for the list.    

repos
    Perform all repo related tasks. Creates and manages our custom repo files.     

selinux
    Configure selinux on yum systems.    

ssh
    Manage things ssh related.  Will upload the distro specific sshd_config, ssh_config and addition of pubkeys for the ``teuthology_user``. 

sudoers
    Manage the /etc/sudoers and the nagios suders.d files.

user
    Manages the ``teuthology_user`` and ``xfstests_user``. 

Dependencies
++++++++++++

This role depends on the following roles:

secrets
    Provides a var, ``secrets_path``, containing the path of the secrets repository, a tree of ansible variable files.
    
sudo
    Sets ``ansible_sudo: true`` for this role which causes all the plays in this role to execute with sudo.

To Do
+++++

- Noop creating custom repos if ``mirror_host`` is not defined.  Change the default to ``mirror_host: ''`` and skip
  creating custom repo files if a mirror is not needed for that specific distro. This is currently hacked in for Vivid.

.. _ceph-qa-chef: https://github.com/ceph/ceph-qa-chef
.. _teuthology: https://github.com/ceph/teuthology
.. _ceph-qa-suite: https://github.com/ceph/ceph-qa-suite
