Overview
========

This project is meant to store ansible roles for managing the nodes in the ceph
testing labs.

Inventory
=========

As this repo only contains roles, it does not define the ansible inventory or
any associated group_vars or host_vars.  However, it does depend on these
things existing in a separate repository or otherwise accesible by these roles
when they are used. Any vars a role needs should be added to its
``defaults/main.yml`` file to document what must be defined per node or group
in your inventory.

This separation is important because we have multiple labs we manage with these
same roles and each lab has different configuration needs. We call these our
``secrets`` or ``*-secrets`` repos throughout the rest of the documention and
in the roles.

Besides the inventory, ``secrets`` repos also may contain certain secret or
encrypted files that we can not include in ceph-cm-ansible for various reasons.

The directory structure for one of our ``secrets`` repos is::

    ├── ansible
        ├── inventory
        │   ├── group_vars
        │   │   ├── all.yml
        │   │   ├── cobbler.yml
        │   │   ├── testnodes.yml
        │   │   ├── teuthology.yml
        │   │   └── typica.yml
        │   └── sepia
        └── secrets
            └── entitlements.yml

Refer to Step 2 below for instructions on how to setup a ``secrets`` repo for
use by ceph-cm-ansible. If set up this way, -i is not necessary for
ansible-playbook to find the repo. However, you can choose your own setup and
point to the ``secrets`` repo with -i if you prefer.

**NOTE:** Some playbooks require specific groups to be defined in your
inventory. Please refer to ``hosts`` in the playbook you want to use to ensure
you've got the proper groups defined.

Where should I put variables?
-----------------------------

All variables should be defined in ``defaults/main.yml`` for the role they're
primarily used in.  If the variable you're adding can be used in multiple roles
define it in ``defaults/main.yml`` for both roles. If the variable can contain
a reasonable default value that should work for all possible labs then define
that value in ``defaults/main.yml`` as well.  If not, you should still default
the variable to something, but make the tasks that use the variable either fail
gracefully without that var or prompt the user to define it if it's mandatory.

If the variable is something that might need to be defined with a value
specific to the lab in use, then it'll need to be added to your ``secrets``
repo as well. Variables in ``group_vars/all.yml`` will apply to all nodes
unless a group_var file exists that is more specific for that node.  For
example, if you define the var ``foo: bar`` in ``all.yml`` and the node you're
running ansible against exists in the ``testnodes`` group and there is a
``group_vars/testnodes.yml`` file defined with ``foo: baz`` included in it then
the role using the variable will use the value defined in ``testnodes.yml``.
The playbook you're using knows which group_var file to use because of the
``hosts`` value defined for it.


Setting up a local dev environment
==================================

We assume that your SSH key is present and active for passwordless access to
the "ubuntu" shell user on the hosts that ansible will manage.

Step 1: Install ansible
-----------------------

You can use pip::

  pip install ansible

or use the OS package manager::
  
  yum install ansible

Step 2: Set up secrets repository
---------------------------------

Clone the secrets repository and symlink the ``hosts`` and ``secrets``
directories into place::

  cd $HOME/src/
  git clone git@github.com:ceph/ceph-sepia-secrets.git

  # If needed, get the path for ceph-octo-secrets from a downstream dev

  sudo mv /etc/ansible/hosts /etc/ansible/hosts.default

  sudo ln -s ~/src/ceph-sepia-secrets/ansible/inventory /etc/ansible/hosts
  sudo ln -s ~/src/ceph-sepia-secrets/ansible/secrets /etc/ansible/secrets

Step 3: Clone the main Ceph ansible repo
----------------------------------------

Clone the main Ceph ansible repository::

  git clone git@github.com:ceph/ceph-cm-ansible.git
  cd ceph-cm-ansible
  
Step 4 (Optional) Modify ``hosts`` files
----------------------------------------
If you have any new hosts on which you'd like to run ansible, or if you're
using separate testing VMs, edit the files in ``/etc/ansible/hosts`` to add
your new (or testing) hosts::

  vi /etc/ansible/hosts/<labname>

If you don't need to test on any new hosts, you can skip this step and just use
``/etc/ansible/hosts`` as-is.

Step 5: Run ``ansible-playbook``
--------------------------------

You can now run ``ansible-playbook``::

  vi myplaybook.yml
  ansible-playbook myplaybook.yml -vv --check --diff

This will print a lot of debugging output to your console.

Adding a new host to ansible
============================

Ansible runs using the "cm" shell account.

Let's say you've created a new VM host using downburst. At this point you
should have a new VM with the "ubuntu" UID present. The problem is that Ansible
uses the "cm" user. In order to get that UID set up:

1. Add your host to the inventory. Look in your lab's ``secrets`` repository,
   in the ``ansible/inventory/`` directory, and add your new node.

2. Run the ``cephlab.yml`` playbook, limited to your new host "mynewhost"::

    ansible-playbook -vv --limit mynewhost cephlab.yml

