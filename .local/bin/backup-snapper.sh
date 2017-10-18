#!/bin/bash
# James W. Barnett (2016-2017)
# Roosembert Palacios (2017)

# Takes snapshots of each snapper configuration. It then sends the snapshot to
# a location on an external drive. After the initial transfer, it does
# incremental snapshots on later calls. It's important not to delete the
# snapshot created on your system since that will be used to determine the
# difference for the next incremental snapshot.

# Destination subvolume will be renamed to date-description replacing everything
# but letters and numbers by '_'.

# Can set the backup directory here, or in the snapper configuration file with
# EXT_BACKUP_LOCATION
if [ -z "$1" ]; then
    echo "No destination directory specified. I hope you set the variable EXT_BACKUP_LOCATION on /etc/snapper/configs/* for each volume"
fi

declare -r MYBACKUPDIR="$1"

# You can set a snapper configuration to be excluded by setting EXT_BACKUP="no"
# in its snapper configuration file.

#--------------------------------------------------------
set -e

if [ "$(id -u)" != '0' ]; then
    echo "Script must be run as root."
    exit
fi

# It's important not to change this userdata in the snapshots, since that's how
# we find the previous one.
declare -r OLD_USERDATA="extbackup=yes"
declare -r NEW_USERDATA="extbackup=please"
declare -r CONFIGS="$(find /etc/snapper/configs/* -printf '%f\n')"

echo "Processing subvolumes $(echo $CONFIGS | tr '\n' ' ')"

for x in $CONFIGS; do
    source /etc/snapper/configs/$x

    DO_BACKUP=${EXT_BACKUP:-"yes"}

    if [[ $DO_BACKUP == "yes" ]]; then

        BACKUPDIR=${EXT_BACKUP_LOCATION:-"$MYBACKUPDIR"}

        if [ -z $BACKUPDIR ]; then
            echo "ERROR: External backup location not set!"
            exit 1
        elif [ ! -d $BACKUPDIR ]; then
            echo "ERROR: $BACKUPDIR is not a directory."
            exit 1
        fi

        OLD_NUMBER=$(snapper -c $x list -t single | grep "$OLD_USERDATA"| awk '/'"$OLD_USERDATA"'/ {print $1}' | head -n 1)
        NEW_NUMBER=$(snapper -c $x list -t single | grep "$NEW_USERDATA"| awk '/'"$NEW_USERDATA"'/ {print $1}' | head -n 1)

        if [[ -z "$NEW_NUMBER" ]]; then
            echo "Target snapshot for configuration $x not found, add extbackup=please as userdata to tag target snapshot. Skipping"
            continue
        fi

        BACKUP_LOCATION="$BACKUPDIR/$x/"
        mkdir -p "$BACKUP_LOCATION"

        NEW_ROW=$(snapper -c $x list -t single | egrep "^$NEW_NUMBER +\|")
        NEW_DATE=$(date --date="$(echo $NEW_ROW | awk -F '|' '{print $2}')" "+%y%m%d-%H%M")
        NEW_ORIG_SNAPSHOT="$SUBVOLUME/.snapshots/$NEW_NUMBER/snapshot"
        NEW_ORIG_INFO="$SUBVOLUME/.snapshots/$NEW_NUMBER/info.xml"
        NEW_DESCRIPTION="$(echo $NEW_ROW | awk -F '|' '{print $4}' | sed 's/^ *//;s/ *$//')"
        NEW_SNAPSHOT_NAME="${NEW_DATE}-$(echo $NEW_DESCRIPTION | sed 's/[^A-Za-z0-9]/_/g')"
        NEW_SNAPSHOT="$SUBVOLUME/.snapshots/$NEW_NUMBER/$NEW_SNAPSHOT_NAME"

        mv "$NEW_ORIG_SNAPSHOT" "$NEW_SNAPSHOT"

        if [[ -z "$OLD_NUMBER" ]]; then
            echo "Will perform initial backup for snapper configuration '$x'."
            echo "Could not calculate total size, I'll still try to transfer though. ETA unknown"
            btrfs send $NEW_SNAPSHOT | pv -pbtea | btrfs receive $BACKUP_LOCATION
            sudo mv "$NEW_SNAPSHOT" "$NEW_ORIG_SNAPSHOT"
        else
            OLD_ROW=$(snapper -c $x list -t single | egrep "^$OLD_NUMBER +\|")
            OLD_DATE=$(date --date="$(echo $OLD_ROW | awk -F '|' '{print $2}')" "+%y%m%d-%H%M")
            OLD_ORIG_SNAPSHOT="$SUBVOLUME/.snapshots/$OLD_NUMBER/snapshot"

            # Sends the difference between the new snapshot and old snapshot to
            # the backup location. Using the -c flag instead of -p tells it that
            # there is an identical subvolume to the old snapshot at the
            # receiving location where it can get its data. This helps speed up
            # the transfer.
            btrfs send -p $OLD_ORIG_SNAPSHOT $NEW_SNAPSHOT | pv -pbtea | btrfs receive -v $BACKUP_LOCATION
            sudo mv "$NEW_SNAPSHOT" "$NEW_ORIG_SNAPSHOT"
            cp "$NEW_ORIG_INFO" "$BACKUP_LOCATION/$NEW_SNAPSHOT_NAME.xml"
            snapper -c $x delete $OLD_NUMBER
        fi

        # Tag new snapshot as the latest
        snapper -v -c $x modify -d "$NEW_DESCRIPTION" -u "$OLD_USERDATA" -c "" $NEW_NUMBER
    fi
done
