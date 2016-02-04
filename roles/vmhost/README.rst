vmhost
======

This role does a lot of the setup for a mira node running Ubuntu
(probably sticking with an LTS of trusty or later is a good idea;
trusty is where it's got the most testing) to turn it into a
'standard' VPS host.  Our standard is: 8 qemu-kvm virtual machines,
provisioned by libvirt through downburst, as noted in the lock
database on paddles for the sepia lab.  The first of those uses
data storage sharing the root drive, and the last seven use
the seven free mira drives as their storage pool.

This role does not set up the storage pool directories/mount
points, and does not add any mapping of which vpm VMs belong
on any particular node (from the vps_hosts group).  It assumes
that you have already:

- created /srv/libvirtpool on the vmhost

- made subdirs there named after the vpms

On mira, we then use disks b..h as separate filesystems to
mount on vpmNNN+1..vpmNNN+7, so for miras, we will have:

- made filesystems (xfs is the usual choice)

- mounted those filesystems on /srv/libvirtpool/<vpm#2--N>

- added UUID= lines to /etc/fstab so the mounts happen at reboot

Note that the role does not assume any particular structure
of what provides /srv/libvirtpool/vpmNNN, but simply uses that
to drive creating libvirt pools.

It is certainly possible to do the above with ansible as well,
and a later version may.


Variables
+++++++++

Only one variable is defined, ``vmhost_apt_packages``.  The default
is empty, but the current definition in vars/ is not expected to change
soon.

Tags
++++

packages
    Just install packages

networking
    Set up the bridge for qemu to use as the 'front' network

libvirt
    All the libvirt-related setup (pools, networks, etc.)
