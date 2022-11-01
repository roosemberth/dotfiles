{ writeShellScriptBin
, btrfs-progs
, coreutils
, e2fsprogs
, gawk
, utillinux
}:
writeShellScriptBin "ensure-nodatacow-btrfs-subvolume"
''
  if ! [ -z "$1" ] && [ -z "$TARGET" ]; then
    TARGET="$1"
    shift
  fi

  if [ -z "$TARGET" ] || [ $# -gt 0 ]; then
    cat <<-EOF
  		$(basename "$0"): Ensure the specified path exists as a btrfs subvolume
  		with the No_COW attribute set.
  		If the specified path does not exist, it is created as a btrfs subvolume
  		and the No_COW attribute is set.

  		Usage:
  		$(basename "$0") <PATH>
  		TARGET="<PATH>" $(basename "$0")
  	EOF
    exit 1
  fi

  TARGET="$(readlink -f "$TARGET")"

  # Is it desirable to inline full paths?
  alias awk="${gawk}/bin/awk"
  alias btrfs="${btrfs-progs}/bin/btrfs"
  alias chattr="${e2fsprogs}/bin/awk"
  alias cut="${coreutils}/bin/cut"
  alias findmnt="${utillinux}/bin/findmnt"
  alias lsattr="${e2fsprogs}/bin/lsattr"

  EXISTING_TARGET_PREFIX="$TARGET"
  while ! [ -d "$EXISTING_TARGET_PREFIX" ]; do
    EXISTING_TARGET_PREFIX="$(dirname "$EXISTING_TARGET_PREFIX")"
  done

  if ! [ "btrfs" = "$(findmnt -DnT "$EXISTING_TARGET_PREFIX" | awk '{print $2}')" ]; then
    echo "The specified 'TARGET' does not reside inside a btrfs mountpoint." >&2
    exit 2
  fi

  MOUNT_POINT="$(findmnt -DnT "$EXISTING_TARGET_PREFIX" | awk '{print $NF}')"
  # Path of the TARGET inside the btrfs mount point.
  SUBPATH="''${TARGET#$MOUNT_POINT/}"

  # Test if the target is already a btrfs subvolume.
  if ! btrfs subvolume list $MOUNT_POINT | grep -Eq "$SUBPATH\$"; then
    # Make sure the parent directory exists
    mkdir -p "$(dirname "$TARGET")"
    btrfs subvolume create "$TARGET"
    chattr -R +C "$TARGET"
  elif ! [ "$(lsattr -d "$TARGET" | cut -c16)" = "C" ]; then
    echo "The specified 'TARGET' exists as a btrfs subvolume but " \
         "does not have the No_COW attribute set." >&2
    exit 3
  fi
''
