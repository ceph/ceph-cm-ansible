reverse_proxy
=============

Manages selected nginx vhosts on the lab's public reverse proxy (soko01,
192.86.31.5).  soko01 fronts the OpenShift routes for pulpito, git,
apt-mirror, status and friends, each through its own Anubis instance.
Those vhosts grew up hand-edited; this role brings them under git one at a
time.  Only the vhosts listed in ``reverse_proxy_sites`` are touched.

Currently managed:

- ``pulpito.conf`` (pulpito.ceph.com), including the GET-only,
  source-IP-allowlisted paddles proxy at ``/_paddles/runs/...`` used by
  external CI dashboards that only need to *read* test results.  paddles
  has no authentication of its own, which is why the location is limited to
  ``GET`` and to the addresses in ``reverse_proxy_paddles_readonly_allow``
  plus ``reverse_proxy_paddles_readonly_allow_extra``.  The rest of
  ``/_paddles/`` and everything else on the vhost is unchanged.

Usage
+++++

soko01 is the lab's VPN gateway: **always preview first** and never run a
non-check play against it without looking at the diff::

    ansible-playbook reverse_proxy.yml --check --diff
    ansible-playbook reverse_proxy.yml

Hosts belong in the ``reverse_proxy`` inventory group.

Variables
+++++++++

Defined in ``roles/reverse_proxy/defaults/main.yml``::

    reverse_proxy_sites:
      - pulpito.conf

    reverse_proxy_paddles_readonly_allow:
      - cidr: 192.86.31.0/24
        comment: lab public /24 (soko01 self-test, vpn-pub)

    reverse_proxy_paddles_readonly_allow_extra: []

Third-party addresses go in the secrets repo, in the proxy host's
``host_vars``, so they stay out of this public repository::

    reverse_proxy_paddles_readonly_allow_extra:
      - cidr: 203.0.113.10
        comment: some team's Jenkins (who to contact)

Consumers use ``https://pulpito.ceph.com/_paddles/runs/...`` with the same
paths paddles serves under ``/runs/`` (run listings, ``/runs/suite/<suite>/``,
``/runs/<name>/``, ``/runs/<name>/jobs/``).  Responses are cached for 60s.
Note the ``href`` fields paddles returns point at the internal
``paddles.front.sepia.ceph.com`` name; consumers should build follow-up
URLs from the run/job names rather than follow those.
