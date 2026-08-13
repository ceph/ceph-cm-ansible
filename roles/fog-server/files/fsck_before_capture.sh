#!/bin/bash
# Sourced by fog.postinit inside the FOG (FOS) boot environment.
# Before a Capture task, force-fsck the target disk's filesystems so
# partclone/resize2fs start from a clean filesystem.
# The sepia-fog-images job in ceph-build.git relies on this hook to fsck
# root filesystems without an extra reboot into a rescue environment.
if [[ "$type" == "up" ]]; then
  for part in $(blkid -o device | grep "^${hd}"); do
    fstype=$(blkid -o value -s TYPE "$part")
    case "$fstype" in
      ext2|ext3|ext4)
        e2fsck -fp "$part" || e2fsck -fy "$part" || true
        ;;
      xfs)
        xfs_repair "$part" || true
        ;;
    esac
  done
fi
