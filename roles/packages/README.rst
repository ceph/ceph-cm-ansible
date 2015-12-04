Packages
========

This role is used to install and remove packages.

Usage
+++++

To install packages, use --extra-vars and pass in lists of packages you
wish to install for both yum and apt based systems.

For example::

    ansible-playbook packages.yml --extra-vars='{"yum_packages": "foo", "apt_packages": ["foo", "bar"]}'

To remove packages, use --extra-vars and pass in the list of packages you wish
to remove while also including the ``cleanup`` variable.

For example::

    ansible-playbook packages.yml --extra-vars='{"yum_packages": "foo", "cleanup": true}'

The following is an example of how you might accomplish this in a teuthology job::

    tasks:
    - ansible:
        repo: https://github.com/ceph/ceph-cm-ansible.git
        playbook: packages.yml
        cleanup: true
        vars:
            yum_packages: "foo" 
            apt_packages:
                - "foo"
                - "bar" 
