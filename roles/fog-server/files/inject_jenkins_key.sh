#!/bin/bash
# Sourced by fog.postdownload inside the FOG (FOS) environment after a
# Deploy task writes the image to disk.  Ensures the jenkins-unprivileged key
# (1Password "Ceph - Upstream" item jenkins-unprivileged; the key the Jenkins
# agent on soko04 uses for lab ansible) is present on the deployed
# filesystem so the sepia-fog-images job in ceph-build.git can reach nodes
# deployed from images captured before the key existed.  The retired
# jenkins-build@soko04 key is dropped from the same file.
if [[ "$type" == "down" ]]; then
  jbkey='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK1Hg5sk/+DbxFvqDBFCfXWktuGSREWva/QP+kfC6fzS jenkins-unprivileged@soko04.front.sepia.ceph.com'
  mnt=/tmp/keyinject
  mkdir -p $mnt
  for part in $(blkid -o device | grep "^${hd}"); do
    fstype=$(blkid -o value -s TYPE "$part")
    case "$fstype" in
      ext2|ext3|ext4|xfs)
        if mount "$part" $mnt 2>/dev/null; then
          ak="$mnt/home/ubuntu/.ssh/authorized_keys"
          if [ -f "$ak" ]; then
            sed -i '/ jenkins-build@soko04\.front\.sepia\.ceph\.com$/d' "$ak"
            grep -qF "jenkins-unprivileged@soko04" "$ak" || echo "$jbkey" >> "$ak"
          fi
          umount $mnt
        fi
        ;;
    esac
  done
fi
