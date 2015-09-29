Teuthology
==========

This role is used to manage the main teuthology node in a lab, e.g.
``teuthology.front.sepia.ceph.com``.

It currently depends on the ``sudo`` and ``users`` roles. 

It also does the following:

- Install dependencies required for ``teuthology``
- Create the ``teuthology`` and ``teuthworker`` users which are used for
  scheduling and executing tests, respectively
- Clone ``teuthology`` repos into ``~/src/teuthology_master`` under those user accounts
- Run ``teuthology``'s ``bootstrap`` script

It currently does NOT do these things:

- Manage crontab entries
- Manage ``teuthology-worker`` processes
- Run ``teuthology-nuke --stale``
