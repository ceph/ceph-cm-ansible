Overview
========

This project is meant to store the configuration for the ceph testing labs.

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

  cd $HOME/dev/
  git clone git@..../ceph-ansible-secrets.git

  sudo mv /etc/ansible/hosts /etc/ansible/hosts.default

  sudo ln -s /path/to/ceph-ansible-secrets/ansible/inventory /etc/ansible/hosts
  sudo ln -s /path/to/ceph-ansible-secrets/ansible/secrets /etc/ansible/secrets

Step 3: Clone the main Ceph ansible repo
----------------------------------------

Clone the main Ceph ansible repository::

  git clone git@..../ceph-cm-ansible.git
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


TODO
====

Gonna use this space as notes.

I see us eventually having the following roles.

Roles:
- common (in progress)
- apache
- testnode (testnodes will have packages and repos that say, magna002 or 001 might not have)
- ssh (might just be in common)
- ntp (client and server?)
- teuthology (i.e. setting up magna001)
- paddles
- pulpito
- vpmhost?  (does a vpm host need special things?)
