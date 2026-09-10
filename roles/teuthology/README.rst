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

``teuthology_old_lrc_fallback``
  When true, the nginx vhost gets a ``try_files`` fallback so requests for
  logs not found under ``archive_base`` are served from a read-only mount of
  the old (pre-migration) LRC cephfs at ``teuthology_old_lrc_root``.  Set to
  true in host_vars (in the secrets repo) for ``soko04.front.sepia.ceph.com``,
  which serves the pre-migration teuthology log archive.

  The mount itself is not managed by this role.  On soko04 it is a manually
  maintained fstab entry using ``ceph-fuse`` (``fuse.ceph``, ``ro,allow_other``)
  because the old LRC cluster issues aes256k service tickets that the host's
  kernel client does not support.

  Default: ``false``

``teuthology_old_lrc_root``
  Filesystem path of the old LRC cephfs mount used by the fallback above.

  Default: ``/www-data/old-lrc``
