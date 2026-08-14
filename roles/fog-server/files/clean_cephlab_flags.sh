#!/bin/bash
# Sourced by fog.postinit inside the FOG (FOS) boot environment.
# Before a Capture task, remove cephlab first-boot flag files and logs from
# the target filesystems.  prep-fog-capture.yml already removes these, but
# the OS keeps running between that playbook and the capture reboot, and a
# NetworkManager dispatcher event in that window can recreate them --
# baking the capture host's hostname into the image (deployed nodes then
# skip hostname configuration and come up as the capture host).  Removing
# them here is deterministic: no OS is running to recreate them.
if [[ "$type" == "up" ]]; then
  mnt=/tmp/cleanflags
  mkdir -p $mnt
  for part in $(blkid -o device | grep "^${hd}"); do
    fstype=$(blkid -o value -s TYPE "$part")
    case "$fstype" in
      ext2|ext3|ext4|xfs)
        if mount "$part" $mnt 2>/dev/null; then
          rm -f \
            $mnt/.cephlab_net_configured \
            $mnt/.cephlab_hostname_set \
            $mnt/ceph-qa-ready \
            $mnt/etc/udev/rules.d/70-persistent-net.rules \
            $mnt/var/log/cephlab-set-hostname.log \
            $mnt/var/log/nm-from-link.log \
            $mnt/var/log/netplan-from-link.log
          umount $mnt
        fi
        ;;
    esac
  done
fi
