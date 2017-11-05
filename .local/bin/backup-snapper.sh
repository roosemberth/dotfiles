#!/usr/bin/env bash
# Roosembert Palacios (2017)

# shellcheck source=/dev/null
# shellcheck disable=2059
# shellcheck disable=2029

# Exit codes
E_SUCCESS=0
E_USER=1
E_NOCMD=127

# It's important not to change this userdata in the snapshots, since that's how
# we find the previous one.
OLD_USERDATA="extbackup=yes"
NEW_USERDATA="extbackup=please"
CONFIGS="$(find /etc/snapper/configs/* -printf '%f\n')"

die()
{
    retval="$1"; shift
    if [ $# -eq 0 ]; then
        cat <&0 >&2
    else
        printf "$@" >&2; echo >&2
    fi
    if [ "$retval" = $E_USER ]; then
        printf "Run with --help for more information.\n" >&2
    fi
    exit "$retval"
}

usage()
{
    cat <<-EOF
	$BASENAME: Backups snapper btrfs snapshots.

	Sends the snapshots configured in /etc/snapper/configs to a local or remote
	(via ssh) location.

	After doing an initial transfer, it does incremental snapshots subsequent calls.
	It's important not to delete the snapshot created on your system since that
	will be used to determine the difference for the next incremental snapshot.

	Only snapshots with 'extbackup=please' in the user_data field will be sent.
	After successfully sending such snapshot the user_data field will change to
	'extbackup=yes'. Subsequent calls will use the snapshot marked with such
	user_data as parent subvolume when invoking btrfs {send,receive}.

	Destination subvolumes will be renamed to the following pattern:
	\$(date +%F-%H%M)-\$(echo \${description} | sed 's/[^A-Za-z0-9]/_/g')
	where description corresponds to the snapper description replacing everything
	but A-Z a-z 0-9 by '_'. ie. '2017-10-06-0130-I_d_cross_the_universe_for_you'

	$BASENAME will ssh multiple times to the remote host. use of an ssh agent is recommended.

	Detected configurations:
	$CONFIGS

	Configurations containing EXT_BACKUP="no" will be silently skipped.

	Usage:
	$BASENAME [-h]

	$BASENAME [-r user@host] -d /destination/path

	Options:
	  -h, --help
	        Show this help message and exit.
	  -r, --remote
	        Destination is in remote host.
	  -d, --dest
	        Destination path.

	Example:
	    $BASENAME --dest /mnt/Freezer/var/stores/Triglav
	            Will send the btrfs snapshots to a local path.
	            btrfs-send ... | btrfs-receive /mnt/Freezer/var/stores/Triglav/
	            ex. Say you have configs "root" and "homes"; whose latest
	            snapshot description is "Hello World".

	            This will create read-only subvolumes
	            - /mnt/Freezer/var/stores/Triglav/root/$(date +%F-%H%M)-Hello_World
	            - /mnt/Freezer/var/stores/Triglav/homes/$(date +%F-%H%M)-Hello_World

	    $BASENAME --remote root@10.13.13.1 --dest /mnt/Freezer/var/stores/Triglav
	            Will send the btrfs snapshots via ssh. ie
	            btrfs-send ... | ssh root@10.13.13.1 btrfs-receive /mnt/Freezer/var/stores/Triglav/
	EOF
}

while [ $# -gt 0 ]; do
    opt="$1"; shift
    case "$opt" in
        (-h|--help) usage; exit ;;
        (-r|--remote) REMOTE_SSH="$1"; shift ;;
        (-d|--dest) BACKUPDIR="$1"; shift ;;
        (-*) die $E_USER 'Unknown option: %s' "$opt" ;;
        (*) die $E_USER 'Trailing argument: %s' "$opt" ;;
    esac
done

#--------------------------------------------------------

set -e

for prog in pv grep awk;
do
    if ! which "$prog"; then
        die $E_NOCMD "$prog must be accessible via PATH"
    fi
done;

if [ "$(id -u)" != '0' ]; then
    die $E_USER "Script must be run as root."
fi

if [ -z "$BACKUPDIR" ]; then
    die $E_USER "ERROR: External backup location not set!"
fi

if [ -z "$REMOTE_SSH" ]; then
    if [ ! -d "$BACKUPDIR" ]; then
        die "$E_USER" "ERROR: $BACKUPDIR is not a directory."
    fi
else
    if ssh "$REMOTE_SSH" '[ ! -d $BACKUPDIR ]' ; then
        die $E_USER "ERROR: $BACKUPDIR is not a directory on remote location."
    fi
fi

echo "Processing subvolumes $(echo $CONFIGS | tr '\n' ' ')"

for x in $CONFIGS; do
    . /etc/snapper/configs/$x

    DO_BACKUP=${EXT_BACKUP:-"yes"}

    if [ "$DO_BACKUP" = "yes" ]; then
        OLD_NUMBER=$(snapper -c "$x" list -t single | grep "$OLD_USERDATA"| awk '/'"$OLD_USERDATA"'/ {print $1}' | head -n 1)
        NEW_NUMBER=$(snapper -c "$x" list -t single | grep "$NEW_USERDATA"| awk '/'"$NEW_USERDATA"'/ {print $1}' | head -n 1)

        if [ -z "$NEW_NUMBER" ]; then
            echo "Target snapshot for configuration $x not found, add extbackup=please as userdata to tag target snapshot. Skipping"
            continue
        fi

        BACKUP_LOCATION="$BACKUPDIR/$x/"
        if [ -z "$REMOTE_SSH" ]; then
            mkdir -p "$BACKUP_LOCATION"
        else
            ssh "$REMOTE_SSH" mkdir -p "$BACKUP_LOCATION"
        fi

        NEW_ROW=$(snapper -c "$x" list -t single | grep -E "^$NEW_NUMBER +\|")
        NEW_DATE=$(date --date="$(echo "$NEW_ROW" | awk -F '|' '{print $2}')" "+%F-%H%M")
        NEW_ORIG_SNAPSHOT="$SUBVOLUME/.snapshots/$NEW_NUMBER/snapshot"
        NEW_ORIG_INFO="$SUBVOLUME/.snapshots/$NEW_NUMBER/info.xml"
        NEW_DESCRIPTION="$(echo "$NEW_ROW" | awk -F '|' '{print $4}' | sed 's/^ *//;s/ *$//')"
        NEW_SNAPSHOT_NAME="${NEW_DATE}-$(echo "$NEW_DESCRIPTION" | sed 's/[^A-Za-z0-9]/_/g')"
        NEW_SNAPSHOT="$SUBVOLUME/.snapshots/$NEW_NUMBER/$NEW_SNAPSHOT_NAME"

        mv "$NEW_ORIG_SNAPSHOT" "$NEW_SNAPSHOT"

        if [ -z "$OLD_NUMBER" ]; then
            echo "Will perform initial backup for snapper configuration '$x'."

            if [ -z "$REMOTE_SSH" ]; then
                btrfs send "$NEW_SNAPSHOT" | pv -pbtea | btrfs receive "$BACKUP_LOCATION"
            else
                btrfs send "$NEW_SNAPSHOT" | pv -pbtea | ssh "$REMOTE_SSH" btrfs receive "$BACKUP_LOCATION"
            fi

            sudo mv "$NEW_SNAPSHOT" "$NEW_ORIG_SNAPSHOT"
        else
            OLD_ORIG_SNAPSHOT="$SUBVOLUME/.snapshots/$OLD_NUMBER/snapshot"

            if [ -z "$REMOTE_SSH" ]; then
                btrfs send -p "$OLD_ORIG_SNAPSHOT" "$NEW_SNAPSHOT" | pv -pbtea | btrfs receive -v "$BACKUP_LOCATION"
            else
                btrfs send -p "$OLD_ORIG_SNAPSHOT"  "$NEW_SNAPSHOT" | pv -pbtea | ssh "$REMOTE_SSH" btrfs receive -v "$BACKUP_LOCATION"
            fi

            sudo mv "$NEW_SNAPSHOT" "$NEW_ORIG_SNAPSHOT"

            if [ -z "$REMOTE_SSH" ]; then
                cp "$NEW_ORIG_INFO" "$BACKUP_LOCATION/$NEW_SNAPSHOT_NAME.xml"
            else
                ssh "$REMOTE_SSH" tee "$BACKUP_LOCATION/$NEW_SNAPSHOT_NAME.xml" < "$NEW_ORIG_INFO" > /dev/null
            fi
            snapper -c "$x" delete "$OLD_NUMBER"
        fi

        # Tag new snapshot as the latest
        snapper -v -c "$x" modify -d "$NEW_DESCRIPTION" -u "$OLD_USERDATA" -c "" "$NEW_NUMBER"
    fi
done

return $E_SUCCESS
