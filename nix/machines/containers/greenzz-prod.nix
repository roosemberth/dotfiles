{ config, pkgs, secrets, ... }: let
  removeCIDR = ip: builtins.head (builtins.split "/" ip);
  hostDataBase = "/mnt/cabinet/minerva-data";
in {
  containers.greenzz-prod = {
    autoStart = true;
    bindMounts.psql-data.hostPath =
      config.roos.container-host.guestMounts.greenzz-prod-psql.hostPath;
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    bindMounts.influxdb.hostPath =
      config.roos.container-host.guestMounts.greenzz-prod-influxdb.hostPath;
    bindMounts.influxdb.mountPoint = "/var/db/influxdb";
    bindMounts.influxdb.isReadOnly = false;
    bindMounts.greenzz-server.hostPath =
      config.roos.container-host.guestMounts.greenzz-prod-server.hostPath;
    bindMounts.greenzz-server.mountPoint = "/var/lib/greenzz-server";
    bindMounts.greenzz-server.isReadOnly = false;
    bindMounts.grafana.hostPath =
      config.roos.container-host.guestMounts.greenzz-prod-grafana.hostPath;
    bindMounts.grafana.mountPoint = "/var/lib/grafana";
    bindMounts.grafana.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 43000 43001 44108 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = config.roos.container-host.nameservers;
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.postgresql = {
        enable = true;
        port = 43002;
        enableTCPIP = true;
        authentication = ''
          local all all                 trust
          host  all all 10.13.0.0/16    md5
          host  all all 10.231.136.1/32 md5
        '';
        ensureDatabases = secrets.greenzz-prod.postgresql-ensure-dbs;
        ensureUsers = secrets.greenzz-prod.postgresql-ensure-users;
        settings.log_connections = true;
      };
      services.influxdb = {
        enable = true;
        extraConfig.http.bind-address = ":44108";
        package = assert !pkgs.lib.versionOlder "2.0" pkgs.influxdb.version;
          pkgs.influxdb;
      };
      services.grafana = {
        enable = true;
        addr = "10.231.136.5";
        port = 43001;
        domain = "greenzz.orbstheorem.ch";
        rootUrl = "https://greenzz.orbstheorem.ch/grafana/";
        extraOptions.SERVER_SERVE_FROM_SUB_PATH = "true";
      };
      systemd.services.greenzz-server = let
        configFile = pkgs.writeTextFile {
          name = "greenzz-server.conf.yml";
          text = with secrets.greenzz-prod; builtins.toJSON {
            db = { inherit (server-db) url username password; };
            influx = { inherit (server-influx) url username password; };
            server.port = 43000;
            greenzz.datasource.dailyPhotos.path =
              "/var/lib/greenzz-server/daily-photos";
          };
        };
      in {
        description = "Greenzz application server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = ''
            ${pkgs.greenzz-server}/bin/greenzz-server \
              --spring.config.location=classpath:/application.properties,${configFile}
          '';
          Restart = "always";
          PrivateTmp = true;
          ProtectHome = "tmpfs";
          ProtectSystem = "strict";
          WorkingDirectory = "/var/lib/greenzz-server";
          User = "greenzz-server";
          Group = "greenzz-server";
        };
      };
      users.users.greenzz-server.uid = 43001;
      users.users.greenzz-server.description = "Greenzz server user";
      users.users.greenzz-server.isSystemUser = true;
      users.users.greenzz-server.group = "greenzz-server";
      users.groups.greenzz-server.gid = 43001;
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.5/24";
    hostBridge = "orion";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 43000; protocol = "tcp"; }
      { hostPort = 43001; protocol = "tcp"; }
      { hostPort = 44108; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.greenzz-prod = {
    in-rules = [
      # DNS
      "-p udp -m udp --dport 53 -j ACCEPT"
      # Database
      "-p tcp -m tcp --dport 5432 -j ACCEPT"
    ];
    ipv4.fwd-rules = [
      # Replies to the reverse proxy
      "-d 10.13.255.101/32 -m state --state RELATED,ESTABLISHED -j ACCEPT"
    ];
  };

  roos.container-host.guestMounts.greenzz-prod-psql = {};
  roos.container-host.guestMounts.greenzz-prod-influxdb = {};
  roos.container-host.guestMounts.greenzz-prod-server = {};
  roos.container-host.guestMounts.greenzz-prod-grafana = {};
}
