{ config, pkgs, secrets, ... }: let
  removeCIDR = ip: builtins.head (builtins.split "/" ip);
in {
  containers.databases = {
    autoStart = true;
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    bindMounts.influxdb.hostPath = "/mnt/cabinet/minerva-data/influxdb";
    bindMounts.influxdb.mountPoint = "/var/db/influxdb";
    bindMounts.influxdb.isReadOnly = false;
    bindMounts.grafana.hostPath = "/mnt/cabinet/minerva-data/grafana";
    bindMounts.grafana.mountPoint = "/var/lib/grafana";
    bindMounts.grafana.isReadOnly = false;
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
      services.influxdb = {
        enable = true;
        extraConfig = {
          http.auth-enabled = true;
          http.bind-address = ":39425";
        };
      };
      # This database is only available from minerva.
      services.grafana = assert config.networking.hostName == "Minerva"; {
        enable = true;
        addr = removeCIDR secrets.network.zkx.Minerva.host4;
        domain = "minerva.int";
        provision.enable = true;
        provision.datasources = secrets.zkx.minerva-grafana-sources;
      };
    };
    ephemeral = true;
    forwardPorts = [
      { hostPort = 3000; protocol = "tcp"; }
      { hostPort = 39425; protocol = "tcp"; }
      { hostPort = 5432; protocol = "tcp"; }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 39425 ];
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
