public_facing
=============

This role is used to manage the various public-facing hosts we have.  Each host has various configs not managed by the ``common`` role.  This playbook aims to:

- Provide automation in the event of disaster recovery
- Automate repeatable tasks
- Automate 'one-off' host or service nuances

Usage
+++++

Example::

  ansible-playbook public_facing.yml --limit="download.ceph.com"

Variables
+++++++++

For the most part, each host will have its own unique variables.  See the playbook comments for details.
