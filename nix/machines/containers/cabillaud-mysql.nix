{ pkgs, ... }:
let publicPort = 37491;
in {
  containers."cabillauddb" = {
    autoStart = true;
    bindMounts.cabillaud-db-data.mountPoint = "/var/lib/mysql";
    bindMounts.cabillaud-db-data.hostPath = "/var/lib/cabillaud-db/mysql";
    bindMounts.cabillaud-db-data.isReadOnly = false;

    config.networking.firewall.allowedTCPPorts = [ 3306 ];
    config.networking.interfaces.eth0.ipv4.routes = [
      { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
    ];
    config.services.mysql.enable = true;
    config.services.mysql.package = pkgs.mariadb;

    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.2/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { containerPort = 3306; hostPort = publicPort; }
    ];
  };

  networking.bridges.containers.interfaces = [];
  networking.interfaces.containers.ipv4.addresses = [
    { address = "10.231.136.1"; prefixLength = 24; }
  ];
  networking.firewall.allowedTCPPorts = [ publicPort ];
  networking.firewall.extraCommands = ''
    # Restrict access from cabillauddb to local network
    iptables -A INPUT -s 10.231.136.2/32 -d 10.13.255.1/32 -j ACCEPT
    iptables -A INPUT -s 10.231.136.2/32 -d 10.13.0.0/16 -j LOG \
      --log-prefix "dropped restricted connection" --log-level 6
    iptables -A INPUT -s 10.231.136.2/32 -d 10.13.0.0/16 -j DROP
  '';

  systemd.services.cabillaud-db-paths = {
    description = "Prepare paths used by MySQL in the cabillaud database.";
    requiredBy = [ "container@cabillauddb.service" ];
    before = [ "container@cabillauddb.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "/var/lib/cabillaud-db/mysql";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
        in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
