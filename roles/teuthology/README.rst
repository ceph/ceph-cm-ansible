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

Variables
---------

``journald_max_retention``
  How long ``systemd-journald`` will retain log entries before rotating them
  out, regardless of disk pressure.  Accepts any value valid for
  ``journald.conf``'s ``MaxRetentionSec`` (e.g. ``7day``, ``30day``).

  Default: ``7day``

``journald_max_use``
  Maximum total disk space the journal may consume under
  ``/var/log/journal``.  Accepts any value valid for ``journald.conf``'s
  ``SystemMaxUse`` (e.g. ``1G``, ``2G``).

  Default: ``2G``
