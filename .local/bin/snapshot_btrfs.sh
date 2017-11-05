#!/usr/bin/env bash
# Created by Orbstheorem, after a thoughtful day, very early in the morning at epfl.
set -e

usage() {
cat <<- dsa
    $0 backup-name subvolume-to-backup [subvolume-to-backup...]
dsa
}

fail(){
    echo "$@"
    exit 1
}

# "Constants"... FIXME: Autodetect? Automount?
ROOT_VOLUME_PATH=/mnt/root-btrfs
SUBVOLUMES_PATH=${ROOT_VOLUME_PATH}/subvolumes

# Prelude
getSubvolumeActivePath(){
    echo "${SUBVOLUMES_PATH}/.__active__/${1}"
}

getSubvolumeSnapshotDestPath(){
    NAME="${2:-auto}"
    echo "${SUBVOLUMES_PATH}/snapshots/${1}/$(date +%y%m%d-%H%M-${NAME})"
}

createSnapshot(){
    SUBVOLUME="$1"
    SNAPSHOT_NAME="${2:-auto}"
    SNAPSHOT_NAME="$(echo "${SNAPSHOT_NAME}" | sed 's/[^a-zA-Z0-9,.]/_/g')"

    SOURCE="$(getSubvolumeActivePath "${SUBVOLUME}")"
    DEST="$(getSubvolumeSnapshotDestPath "${SUBVOLUME}" "${SNAPSHOT_NAME}")"

    [ -d "${SOURCE}" ]  || fail "Couldn't fin active subvolume on path: ${SOURCE}"
    [ ! -d "${DEST}" ]  || fail "Destination path already exists!: ${DEST}"

    [ -d "$(dirname ${SUBVOLUMES_PATH})" ] || fail "Snapshot destination path does not exist!"

    btrfs subvolume snapshot -r "${SOURCE}" "${DEST}"
}

if [ $(whoami) != "root" ]; then
    exec sudo $0 $@
fi
# Check we received at least two arguments
if [ $# -lt 2 ]; then
    usage
    fail "Not enough arguments"
fi

NAME="${1:-auto}"
shift

while [ $# -gt 0 ]; do
    createSnapshot "$1" "$NAME"
    shift
done
