{ config, pkgs, secrets, ... }: let
  removeCIDR = ip: builtins.head (builtins.split "/" ip);
in {
  containers.greenzz = {
    autoStart = true;
    bindMounts.psql-data.hostPath = "/mnt/cabinet/minerva-data/greenzz-psql";
    bindMounts.psql-data.mountPoint = "/var/lib/postgresql";
    bindMounts.psql-data.isReadOnly = false;
    bindMounts.influxdb.hostPath = "/mnt/cabinet/minerva-data/greenzz-influxdb";
    bindMounts.influxdb.mountPoint = "/var/db/influxdb";
    bindMounts.influxdb.isReadOnly = false;
    bindMounts.grafana.hostPath = "/mnt/cabinet/minerva-data/greenzz-grafana";
    bindMounts.grafana.mountPoint = "/var/lib/grafana";
    bindMounts.grafana.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 44104 44105 44106 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = [ "1.1.1.1" ];
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.postgresql = {
        enable = true;
        port = 44104;
        enableTCPIP = true;
        authentication = ''
          local all all                 trust
          host  all all 10.13.0.0/16    md5
          host  all all 10.231.136.1/32 md5
        '';
        ensureDatabases = secrets.greenzz.postgresql-ensure-dbs;
        ensureUsers = secrets.greenzz.postgresql-ensure-users;
        settings.log_connections = true;
      };
      services.influxdb = {
        enable = true;
        extraConfig = {
          http.auth-enabled = true;
          http.bind-address = ":44105";
        };
      };
      # This database is only available from minerva.
      services.grafana = {
        enable = true;
        addr = "10.231.136.3";
        port = 44106;
        domain = "orbstheorem.ch";
        provision.enable = true;
        provision.datasources = secrets.greenzz.minerva-grafana-sources;
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.3/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 44104; protocol = "tcp"; }
      { hostPort = 44105; protocol = "tcp"; }
      { hostPort = 44106; protocol = "tcp"; }
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
    iptables -A INPUT -s 10.231.136.3/32 -j LOG \
      --log-prefix "dropped restricted connection" --log-level 6
    iptables -A INPUT -s 10.231.136.3/32 -j DROP
    iptables -A FORWARD -s 10.231.136.3/32 -d 10.13.255.5/32 -j ACCEPT
    iptables -A FORWARD -s 10.231.136.3/32 -o ${exitIface} -j ACCEPT
    iptables -A FORWARD -s 10.231.136.3/32 -j LOG \
      --log-prefix "dropped restricted fwd connection" --log-level 6
    iptables -A FORWARD -s 10.231.136.3/32 -j DROP
  '';

  systemd.services.greenzz-psql-paths = {
    description = "Prepare paths used by PostgreSQL.";
    requiredBy = [ "container@greenzz.service" ];
    before = [ "container@greenzz.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "/mnt/cabinet/minerva-data/greenzz-psql";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
      in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
