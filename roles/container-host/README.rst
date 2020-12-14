container-host
==============

The container-host role will:

- Install ``docker`` or ``podman``
- Configure a local ``docker.io`` mirror if configured

Variables
+++++++++

``container_packages: []`` is the list of container packages to install.  We default to podman on RedHat based distros and docker.io on Debian-based distros.

The following variables are used to optionally configure a docker.io mirror CA certificate. The role will use ``/etc/containers/certs.d`` if ``podman`` is installed and ``/etc/docker/certs.d`` if ``docker`` is installed.::

    # Defined in all.yml in secrets repo
    container_mirror: docker-mirror.front.sepia.ceph.com:5000

    # Defined in all.yml in secrets repo
    container_mirror_cert: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----

    # Automatically determined in roles/container-host/tasks/main.yml
    container_mirror_cert_path: "/etc/docker/certs.d/{{ container_mirror }}"

Tags
++++

registries-conf-ctl
    Add ``--skip-tags registries-conf-ctl`` to your ``ansible-playbook`` command if you don't want to use registries-conf-ctl_ to configure the container service's conf file.

.. _registries-conf-ctl: https://github.com/sebastian-philipp/registries-conf-ctl
