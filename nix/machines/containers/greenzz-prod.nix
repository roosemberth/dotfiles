{ config, pkgs, secrets, ... }: let
  removeCIDR = ip: builtins.head (builtins.split "/" ip);
  hostDataBase = "/mnt/cabinet/minerva-data";
in {
  containers.greenzz-prod = {
    autoStart = true;
    bindMounts.psql-data.hostPath = "${hostDataBase}/greenzz-prod-psql";
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    bindMounts.influxdb.hostPath = "${hostDataBase}/greenzz-prod-influxdb";
    bindMounts.influxdb.mountPoint = "/var/db/influxdb";
    bindMounts.influxdb.isReadOnly = false;
    bindMounts.greenzz-server.hostPath = "${hostDataBase}/greenzz-prod-server";
    bindMounts.greenzz-server.mountPoint = "/var/lib/greenzz-server";
    bindMounts.greenzz-server.isReadOnly = false;
    bindMounts.grafana.hostPath = "/mnt/cabinet/minerva-data/greenzz-prod-grafana";
    bindMounts.grafana.mountPoint = "/var/lib/grafana";
    bindMounts.grafana.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 43000 43001 44108 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = [ "1.1.1.1" ];
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
      users.groups.greenzz-server.gid = 43001;
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.5/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 43000; protocol = "tcp"; }
      { hostPort = 43001; protocol = "tcp"; }
      { hostPort = 44108; protocol = "tcp"; }
    ];
  };

  networking.bridges.containers.interfaces = [];
  networking.interfaces.containers.ipv4.addresses = [
    { address = "10.231.136.1"; prefixLength = 24; }
  ];
  networking.nat.internalInterfaces = ["containers"];
  networking.firewall.extraCommands = let
    exitIface = config.networking.nat.externalInterface;
  in ''
    # Restrict access to hypervisor network
    iptables -A INPUT -s 10.231.136.5/32 -j LOG \
      --log-prefix "dropped restricted connection" --log-level 6
    iptables -A INPUT -s 10.231.136.5/32 -j DROP
    iptables -A FORWARD -s 10.231.136.5/32 -d 10.13.255.5/32 -j ACCEPT
    iptables -A FORWARD -s 10.231.136.5/32 -o ${exitIface} -j ACCEPT
    iptables -A FORWARD -s 10.231.136.5/32 -j LOG \
      --log-prefix "dropped restricted fwd connection" --log-level 6
    iptables -A FORWARD -s 10.231.136.5/32 -j DROP
  '';

  systemd.services.greenzz-prod-psql-paths = {
    description = "Prepare paths used by PostgreSQL.";
    requiredBy = [ "container@greenzz-prod.service" ];
    before = [ "container@greenzz-prod.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "/mnt/cabinet/minerva-data/greenzz-prod-psql";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
      in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
