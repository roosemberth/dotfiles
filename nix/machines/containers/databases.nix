{ config, pkgs, lib, secrets, roosModules, ... }: let
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
      imports = roosModules;
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      systemd.services.systemd-networkd-wait-online = lib.mkForce {};

      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";

      roos.firewall.networks.lan = {
        ifaces.eth0 = {};
        in6-rules = [
          "-p udp -m udp --dport 5355 -j ACCEPT" # LLMNR
          "-p tcp -m tcp --dport 3000 -j ACCEPT"
          "-p tcp -m tcp --dport 39425 -j ACCEPT"
          "-p tcp -m tcp --dport 5432 -j ACCEPT"
        ];
      };

      services.postgresql = {
        enable = true;
        enableTCPIP = true;

        authentication = let
          warn = msg: builtins.trace "[1;31mwarning: ${msg}[0m";
        in warn "The database auth method is globally adressable and insecure." ''
          local all all               trust
          # Global IPv6, in the firewall we trust.
          host  all all ::/0          md5
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
      services.grafana = {
        enable = true;
        addr = "::/0";
        provision.enable = true;
        provision.datasources = secrets.zkx.minerva-grafana-sources;
      };
      services.prometheus.exporters.postgres.enable = true;
      system.stateVersion = "22.05";
    };
    ephemeral = true;
    hostBridge = "orion";
    privateNetwork = true;
  };

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
