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

Another dictionary of yum repos to put in place.  We have this dictionary defined in the Octo lab secrets repo.  We have devel
repos with baseurls we don't want to expose the URLs of.  This dict gets combined with ``yum_repos`` in ``roles/testnode/tasks/yum/repos.yml``::

    additional_yum_repos: {}
    
    # An example:
    additional_yum_repos:
      devel-ceph-repo:
        name: This is a repo with devel packages
        baseurl: http://some/private/repo/
        enabled: 0
        gpgcheck: 0

A list of copr repos to enable using ``dnf copr enable``::

    copr_repos: []

    # An example:
    copr_repos:
      - ktdreyer/ceph-el8

A list of mirrorlist template **filenames** to upload to ``/etc/yum.repos.d/``.
Mirrorlist templates should live in ``roles/testnode/vars/mirrorlists/{{ ansible_distribution_major_version }}/``
We were already doing this with epel mirrorlists in the ``common`` role but started seeing metalink issues with CentOS repos::

    yum_mirrorlists: []

    # Example:
    yum_mirrorlists:
      - CentOS-AppStream-mirrorlist

    $ cat roles/testnode/templates/mirrorlists/8/CentOS-AppStream-mirrorlist
    # {{ ansible_managed }}
    https://download-cc-rdu01.fedoraproject.org/pub/centos/{{ ansible_lsb.release }}/AppStream/x86_64/os/
    https://path/to/another/mirror


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

A list of packages to install via ``apt install --no-install-recommends``::

    no_recommended_packages: []

A list of packages to install via pip. These lists are defined in the vars files in ``vars/``::

    pip_packages_to_install: []

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

A dictionary of drives/devices you want to partition.  ``scratch_devs`` is not required.  All other values are self-explanatory given this example::

    # Example:
    drives_to_partition:
      nvme0n1:
        device: "/dev/nvme0n1"
        unit: "GB"
        sizes:
          - "0 95"
          - "95 190"
          - "190 285"
          - "285 380"
          - "380 400"
        scratch_devs:
          - p1
          - p2
          - p3
          - p4
      sdb:
        device: "/dev/sdb"
        unit: "%"
        sizes:
          - "0 50"
          - "50 100"
        scratch_devs:
          - 2

An optional dictionary of filesystems you want created and where to mount them.  (You must use a ``drives_to_partition`` or ``logical_volumes`` dictionary to carve up drives first.)  Example::

    filesystems:
      varfoo:
        device: "/dev/nvme0n1p5"
        fstype: ext4
        mountpoint: "/var/lib/foo"
      fscache:
        device: "/dev/nvme0n1p6"
        fstype: xfs
        mountpoint: "/var/cache/fscache"

A dictionary of volume groups you want created.  ``pvs`` should be a comma-delimited list.  Example::

    volume_groups:
      vg_nvme:
        pvs: "/dev/nvme0n1"
      vg_hdd:
        pvs: "/dev/sdb,/dev/sdc"

A dictionary of logical volumes you want created.  See Ansible's docs_ on available sizing options.  The ``vg`` value is the volume group you want the logical volume created on.  Define ``scratch_dev`` if you want it added to ``/scratch_devices`` on the testnode::

    logical_volumes:
      lv_1:
        vg: vg_nvme
        size: "25%VG"
        scratch_dev: true
      lv_2:
        vg: vg_nvme
        size: "75%VG"
        scratch_dev: true
      lv_foo:
        vg: vg_hdd
        size: "100%VG"

Setting ``quick_lvs_to_create`` will:

    #. Create one large volume group using all non-root devices listed in ``ansible_devices``
    #. Create X number of logical volumes equal in size

    Defining this variable will override ``volume_groups`` and ``logical_volumes`` dicts if defined in secrets::

        # Example would create 4 logical volumes each using 25% of a volume group created using all non-root physical volumes
        quick_lvs_to_create: 4

Define ``check_for_nvme: true`` in Ansible inventory group_vars (by machine type) if the testnode should have an NVMe device.  This will include a few tasks to verify an NVMe device is present.  If the drive is missing, the tasks will mark the testnode down in the paddles_ lock database so the node doesn't repeatedly fail jobs.  Defaults to false::

    check_for_nvme: false

Downstream QE requested ABRT be configured in a certain way.  Overridden in Octo secrets::

    configure_abrt: false

Configure ``cachefilesd``.  See https://tracker.ceph.com/issues/6373.  Defaults to ``false``::

    configure_cachefilesd: true

    # Optionally override any of the following variables to change their
    # corresponding values in /etc/cachefilesd.conf
    cachefilesd_dir
    cachefilesd_tag
    cachefilesd_brun
    cachefilesd_bcull
    cachefilesd_bstop
    cachefilesd_frun
    cachefilesd_fcull
    cachefilesd_fstop
    cachefilesd_secctx

Include the grafana_agent role to report testnode resource statistics to Grafana.  Defaults to ``false``::

    run_grafana_agent_role: true


Tags
++++

Available tags are listed below:

cachefilesd
    Install and configure cachefilesd.

cpan
    Install and configure cpan and Amazon::S3.

filesystems
    Create and mount filesystems.

gpg-keys
    Install gpg keys on Fedora.    

hostname
    Check and set proper fqdn. See, ``roles/testnode/tasks/set_hostname.yml``.

lvm
    Configures logical volumes if dicts are defined in the secrets repo.

nfs
    Install and start nfs.

ntp-client
    Setup ntp.

packages
    Install, update and remove packages.

partition
    Partition any drives/devices if ``drives_to_partition`` is defined in secrets.

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

zap
    Zap (``sgdizk -Z``) all non-root drives and **all** logical volumes and volume groups

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
.. _docs: https://docs.ansible.com/ansible/latest/lvol_module.html
.. _paddles: https://github.com/ceph/paddles
