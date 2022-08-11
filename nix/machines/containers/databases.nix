{ config, pkgs, secrets, ... }: let
  removeCIDR = ip: builtins.head (builtins.split "/" ip);
  hostDataDirBase = "/mnt/cabinet/minerva-data";
in {
  containers.databases = {
    autoStart = true;
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    bindMounts.influxdb.hostPath = "${hostDataDirBase}/influxdb";
    bindMounts.influxdb.mountPoint = "/var/db/influxdb";
    bindMounts.influxdb.isReadOnly = false;
    bindMounts.grafana.hostPath = "${hostDataDirBase}/grafana";
    bindMounts.grafana.mountPoint = "/var/lib/grafana";
    bindMounts.grafana.isReadOnly = false;
    config = {
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          local all all               trust
          # Site network
          host  all all 10.13.0.1/16  md5
          # ipv4 containers on this host
          host  all all 10.231.0.0/16 md5
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
      services.prometheus.exporters.postgres.enable = true;
      system.stateVersion = "22.05";
    };
    ephemeral = true;
    forwardPorts = [
      { hostPort = 3000; protocol = "tcp"; }
      { hostPort = 39425; protocol = "tcp"; }
      { hostPort = 5432; protocol = "tcp"; }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 39425 ];

  systemd.services."container@databases".unitConfig.ConditionPathIsDirectory = [
    "/var/lib/postgresql"
    "${hostDataDirBase}/influxdb"
    "${hostDataDirBase}/grafana"
  ];
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
    unitConfig.ConditionPathIsDirectory = [ "/var/lib/postgresql" ];
  };
}
