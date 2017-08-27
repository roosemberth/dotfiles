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
declare -r mybackupdir="/mnt/then/var/stores/Triglav"

# You can set a snapper configuration to be excluded by setting EXT_BACKUP="no"
# in its snapper configuration file.

#--------------------------------------------------------
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Script must be run as root."
    exit
fi

# It's important not to change this userdata in the snapshots, since that's how
# we find the previous one.
declare -r old_userdata="extbackup=yes"
declare -r new_userdata="extbackup=please"
declare -r configs="$(find /etc/snapper/configs/* -printf '%f\n')"

echo "Processing subvolumes $(echo $configs | tr '\n' ' ')"

for x in $configs; do
    source /etc/snapper/configs/$x

    do_backup=${EXT_BACKUP:-"yes"}

    if [[ $do_backup == "yes" ]]; then

        BACKUPDIR=${EXT_BACKUP_LOCATION:-"$mybackupdir"}

        if [[ -z $BACKUPDIR ]]; then
            echo "ERROR: External backup location not set!"
            exit 1
        elif [[ ! -d $BACKUPDIR ]]; then
            echo "ERROR: $BACKUPDIR is not a directory."
            exit 1
        fi

        old_number=$(snapper -c $x list -t single | grep "$old_userdata"| awk '/'"$old_userdata"'/ {print $1}' | head -n 1)
        new_number=$(snapper -c $x list -t single | grep "$new_userdata"| awk '/'"$new_userdata"'/ {print $1}' | head -n 1)

        if [[ -z "$new_number" ]]; then
            echo "Target snapshot for configuration $x not found, add extbackup=please as userdata to tag target snapshot. Skipping"
            continue
        fi

        backup_location="$BACKUPDIR/$x/"
        mkdir -p "$backup_location"

        new_row=$(snapper -c $x list -t single | egrep "^$new_number +\|")
        new_date=$(date --date="$(echo $new_row | awk -F '|' '{print $2}')" "+%y%m%d-%H%M")
        new_orig_snapshot="$SUBVOLUME/.snapshots/$new_number/snapshot"
        new_orig_info="$SUBVOLUME/.snapshots/$new_number/info.xml"
        new_description="$(echo $new_row | awk -F '|' '{print $4}' | sed 's/^ *//;s/ *$//')"
        new_snapshot_name="${new_date}-$(echo $new_description | sed 's/[^A-Za-z0-9]/_/g')"
        new_snapshot="$SUBVOLUME/.snapshots/$new_number/$new_snapshot_name"

        mv "$new_orig_snapshot" "$new_snapshot"

        if [[ -z "$old_number" ]]; then
            echo "Will perform initial backup for snapper configuration '$x'. Calculating Transfer size..."
            size=$(btrfs filesystem du -s --raw $new_snapshot | tail -n 1 | awk '{print $1}')
            echo "Performing initial backup. Transfer size: $size bytes"
            btrfs send -v $new_snapshot | pv -pbteas $size | btrfs receive -v $backup_location
            sudo mv "$new_snapshot" "$new_orig_snapshot"
        else
            old_row=$(snapper -c $x list -t single | egrep "^$old_number +\|")
            old_date=$(date --date="$(echo $old_row | awk -F '|' '{print $2}')" "+%y%m%d-%H%M")
            old_orig_snapshot="$SUBVOLUME/.snapshots/$old_number/snapshot"
            #old_snapshot="$SUBVOLUME/.snapshots/$old_number/${old_date}-$(echo $old_row | awk -F '|' '{print $4}' | sed 's/^ *//;s/ *$//;s/[^A-Za-z0-9]/_/g')"

            #sudo btrfs subvolume snapshot -r "$old_orig_snapshot" "$old_snapshot" || true

            # Sends the difference between the new snapshot and old snapshot to
            # the backup location. Using the -c flag instead of -p tells it that
            # there is an identical subvolume to the old snapshot at the
            # receiving location where it can get its data. This helps speed up
            # the transfer.
            btrfs send -p $old_orig_snapshot -v $new_snapshot | pv -pbtea | btrfs receive -v $backup_location
            sudo mv "$new_snapshot" "$new_orig_snapshot"
            cp "$new_orig_info" "$backup_location/$new_snapshot_name.xml"
            snapper -c $x delete $old_number
        fi

        # Tag new snapshot as the latest
        snapper -v -c $x modify -d "$new_description" -u "$old_userdata" -c "" $new_number
    fi
done
