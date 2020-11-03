{ config, pkgs, lib, secrets, ... }: with lib;
{
  options.roos.eivd.enable =
    mkEnableOption "Stuff required during my studies at HEIG-VD";

  config = mkIf config.roos.eivd.enable {
    networking.bridges.containers.interfaces = [];
    networking.bridges.containers.rstp = true;

    containers."eivd-mysql" = {
      bindMounts.eivd-mysql-data.mountPoint = "/var/lib/mysql";
      bindMounts.eivd-mysql-data.hostPath = "/var/lib/eivd-mysql/mysql";
      bindMounts.eivd-mysql-data.isReadOnly = false;
      config = {
        services.mysql.enable = true;
        services.mysql.package = pkgs.mariadb;
      };
      ephemeral = true;
      hostBridge = "containers";
      privateNetwork = true;
    };

    roos.sConfig = {
      home.packages = with pkgs; [
        # POO1
        (maven.override { jdk = openjdk14; })
        openjdk14
      ];
    };

    roos.gConfig = {
      home.packages = with pkgs; [ teams ];
    };

    systemd.services.eivd-mysql = {
      description = "Prepare paths used by MySQL in the eivd container.";
      requiredBy = [ "container@eivd-mysql.service" ];
      before = [ "container@eivd-mysql.service" ];
      path = with pkgs; [
        btrfs-progs
        e2fsprogs
        gawk
        utillinux
      ];
      environment.TARGET = "/var/lib/eivd-mysql/mysql";
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
        '';
      };
    };
  };
}
