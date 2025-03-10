#!/bin/sh

if [ -z "$1" ]; then
  ROOTFS_DEVICE="@rootfsDevice@"
else
  ROOTFS_DEVICE="$1"
fi

if [ "$(blkid -o value -s TYPE "$ROOTFS_DEVICE")" != "btrfs" ]; then
  echo -n "WARNING: The fstype of the rootfs device ($ROOTFS_DEVICE) " >&2
  echo "is not btrfs. Active subvolume versions will not be rotated." >&2
else
  # Mount the rootfs in a temporary directory, create a new subvolume to hold
  # a new version of some subvolumes, swap the active version and finally
  # unmount the rootfs.
  TMP_MOUNT_DIR="$(mktemp -d -t 'rootfs.XXXXXX')"
  mkdir "$TMP_MOUNT_DIR"
  mount -t btrfs "$ROOTFS_DEVICE" "$TMP_MOUNT_DIR"
  cd "$TMP_MOUNT_DIR/subvolumes/versioned"

  EPH_VERSION="$(date -u +%y%m%dZ%H%M)"
  mkdir -p "$EPH_VERSION"
  for v in $(ls -v1 templates); do  # Generate new volume versions from template
    btrfs subvolume snapshot "templates/$v" "$EPH_VERSION/$v"
  done
  rm -f active
  ln -sf "$EPH_VERSION" active

  for v in $(ls -v1 | grep -v templates); do
    if ! date -d "$v" &> /dev/null; then
      echo -n "WARNING: Could not determine whether to clean up " >&2
      echo "subvolume version $v" >&2
      continue
    fi
    if [ $(date -d "$v" +%s) -lt $(date 'now - 7 days' +%s) ]; then
      echo "Deleting old subvolume version $v"
      for sv in $(ls -v1 "$v"); do
        btrfs subvolume delete "$v/$sv"
      done
      rm -fr "$v"
    fi
  done

  cd
  umount "$TMP_MOUNT_DIR"
  rmdir "$TMP_MOUNT_DIR"
fi
