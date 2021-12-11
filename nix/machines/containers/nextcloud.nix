{ config, pkgs, secrets, ... }: let
  hostDataDirBase = "/mnt/cabinet/minerva-data";
in {
  containers.nextcloud = {
    autoStart = true;
    bindMounts.nextcloud.hostPath = "${hostDataDirBase}/nextcloud";
    bindMounts.nextcloud.mountPoint = "/var/lib/nextcloud";
    bindMounts.nextcloud.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 80 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = [ "1.1.1.1" ];
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.nextcloud = {
        enable = true;
        home = "/var/lib/nextcloud";
        https = true;
        hostName = "nextcloud.orbstheorem.ch";
        maxUploadSize = "50G";
        enableImagemagick = true;
        autoUpdateApps.enable = true;
        config.adminuser = secrets.nextcloud.adminuser;
        config.adminpass = secrets.nextcloud.adminpass;
        config.dbuser = secrets.nextcloud.dbuser;
        config.dbpass = secrets.nextcloud.dbpass;
        config.dbtype = "pgsql";
        config.dbport = "5432";
        config.dbhost = "minerva.intranet.orbstheorem.ch";
        config.defaultPhoneRegion = "CH";
        config.overwriteProtocol = "http";
      };
      services.prometheus.exporters.nextcloud = {
        # FIXME
        enable = false; # true;
        url = "http://localhost";
        port = 26224;
        username = secrets.nextcloud.exporteruser;
        passwordFile = pkgs.writeText
          secrets.nextcloud.exporterpassfilename
          secrets.nextcloud.exporterpass;
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.7/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 42080; containerPort = 80; protocol = "tcp"; }
      { hostPort = 26224; protocol = "tcp"; }
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
    # Allow a database connection.
    iptables -A INPUT -s 10.231.136.7/32 -d 10.13.255.13 \
      -p tcp -m tcp --dport 5432 -j ACCEPT
    # Restrict access to hypervisor network
    iptables -A INPUT -s 10.231.136.7/32 -j LOG \
      --log-prefix "dropped restricted connection" --log-level 6
    iptables -A INPUT -s 10.231.136.7/32 -j DROP
    iptables -A FORWARD -s 10.231.136.7/32 -d 10.13.255.101/32 -j ACCEPT
    iptables -A FORWARD -s 10.231.136.7/32 -o ${exitIface} -j ACCEPT
    iptables -A FORWARD -s 10.231.136.7/32 -j LOG \
      --log-prefix "dropped restricted fwd connection" --log-level 6
    iptables -A FORWARD -s 10.231.136.7/32 -j DROP
  '';

  systemd.services.nextcloud-paths = {
    description = "Prepare paths used by nextcloud.";
    requiredBy = [ "container@nextcloud.service" ];
    before = [ "container@nextcloud.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "/var/lib/nextcloud";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
      in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
