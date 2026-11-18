jenkins-unprivileged
====================

Creates the ``jenkins-unprivileged`` user the Jenkins agent on the teuthology host
(``soko04``) uses to reach lab infrastructure hosts, instead of the
root-equivalent ``cm`` user.  Its only sudo right is ``/usr/local/sbin/pxe-target
<host> <fog|maas>``, which flips a testnode's ``dhcp-host=set:...`` tag in the
dnsmasq config and restarts dnsmasq (the ``sepia-fog-images`` job's
``STARTWITHMAAS`` and ``FSCKMETHOD=maas-rescue`` paths).

Variables
+++++++++

``jenkins_unprivileged_ssh_keys``
  Public keys authorized for the user (exclusive).  The Sepia inventory sets
  it to the ``jenkins-unprivileged`` key (1Password vault "Ceph - Upstream").
``pxe_target_dnsmasq_conf``
  dnsmasq config file with the ``dhcp-host`` lines; default
  ``/etc/dnsmasq.d/pok/front.conf``.

Applied by ``jenkins-unprivileged.yml`` to the ``jenkins_unprivileged_hosts`` inventory group.
