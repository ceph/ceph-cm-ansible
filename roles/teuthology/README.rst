Teuthology
==========

This role is used to manage the main teuthology node in a lab, e.g.
``teuthology.front.sepia.ceph.com``.

It only depends on the ``common`` role.

It also does the following:

- Install dependencies required for ``teuthology``
- Create the ``teuthology`` and ``teuthworker`` users which are used for
  scheduling and executing tests, respectively
- Clone ``teuthology`` repos into ``~/src/teuthology_main`` under those user accounts
- Run ``teuthology``'s ``bootstrap`` script
- Manages user accounts and sudo privileges using the ``test_admins`` group_var in the secrets repo
- Includes a script to keep the ``teuthology`` user's crontab up to date with remote version-controlled versions (``--tags="crontab")

It currently does NOT do these things:

- Manage ``teuthology-worker`` processes
- Run ``teuthology-nuke --stale``
