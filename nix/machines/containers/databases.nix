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
      ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
      in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
