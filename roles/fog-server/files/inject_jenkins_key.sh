#!/bin/bash
# Sourced by fog.postdownload inside the FOG (FOS) environment after a
# Deploy task writes the image to disk.  Ensures the jenkins-build@soko04
# key (also in ceph-sepia-secrets group_vars/all.yml) is present on the
# deployed filesystem so the sepia-fog-images job in ceph-build.git can
# reach nodes deployed from images captured before the key existed.
if [[ "$type" == "down" ]]; then
  jbkey='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGRpTKfYlFn7eSAprIL+ENT/cIgGV7uvSt+Fgnzuy1nM jenkins-build@soko04.front.sepia.ceph.com'
  mnt=/tmp/keyinject
  mkdir -p $mnt
  for part in $(blkid -o device | grep "^${hd}"); do
    fstype=$(blkid -o value -s TYPE "$part")
    case "$fstype" in
      ext2|ext3|ext4|xfs)
        if mount "$part" $mnt 2>/dev/null; then
          ak="$mnt/home/ubuntu/.ssh/authorized_keys"
          if [ -f "$ak" ] && ! grep -qF "jenkins-build@soko04" "$ak"; then
            echo "$jbkey" >> "$ak"
          fi
          umount $mnt
        fi
        ;;
    esac
  done
fi
