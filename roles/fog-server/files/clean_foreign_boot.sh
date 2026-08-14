#!/bin/bash
# Sourced by fog.postdownload inside the FOG (FOS) environment after a
# Deploy task writes the image to disk.  Sidelines EFI bootloader files on
# ESPs of disks OTHER than the deploy target so stale installs (e.g. an old
# MAAS deployment on a repurposed node) can't hijack the UEFI boot order.
# Without this, the firmware/rEFInd can chainload the leftover install's
# GRUB, whose BLS entries reference filesystems the deploy just destroyed
# (observed as a kernel panic: VFS unable to mount root fs).
# The directory is renamed, not deleted, so this is reversible.
# Only runs for smithi/trial testnodes (which includes trial-perf); other
# FOG-managed hosts are left alone.
if [[ "$type" == "down" ]]; then
  case "$hostname" in
    trial*|smithi*)
      mnt=/tmp/foreignesp
      mkdir -p $mnt
      for part in $(blkid -o device); do
        case "$part" in
          ${hd}*) continue ;;
        esac
        fstype=$(blkid -o value -s TYPE "$part")
        if [[ "$fstype" == "vfat" ]]; then
          if mount "$part" $mnt 2>/dev/null; then
            if [[ -d $mnt/EFI ]]; then
              echo "Sidelining stale EFI dir on foreign ESP $part"
              rm -rf $mnt/EFI.stale
              mv $mnt/EFI $mnt/EFI.stale
            fi
            umount $mnt
          fi
        fi
      done
      ;;
  esac
fi
