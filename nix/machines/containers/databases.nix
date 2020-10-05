{ config, pkgs, secrets, ... }:
{
  containers.databases = {
    autoStart = true;
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    config = {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          local all all              trust
          host  all all 10.13.0.1/16 md5
        '';
        settings.log_connections = true;
      };
    };
    ephemeral = true;
    forwardPorts = [ { hostPort = 5432; protocol = "tcp"; } ];
  };

  networking.search = with secrets.network.zksDNS; [ search ];
  networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;

  systemd.services.postgresql-paths = {
    description = "Prepare paths used by PostgreSQL.";
    requiredBy = [ "container@databases.service" ];
    before = [ "container@databases.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "/var/lib/postgresql";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ensure-nodatacow-btrfs-subvolme" ''
        # Ensures the specified target exists as a btrfs subvolume and has
        # the No_COW attribute set.
        # If the specified TARGET does not exist, it is created as a btrfs
        # subvolume and the No_COW attribute is set.

        if [ -z "$TARGET" ]; then
          echo "Missing required environment variable 'TARGET'." >&2
          exit 1
        fi

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
        SUBPATH="$${TARGET#$MOUNT_POINT/}"

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
      '';
    };
  };
}
