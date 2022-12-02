{ config, lib, pkgs, secrets, ... }: let
  fsec = config.sops.secrets;
in {
  containers.nextcloud = {
    autoStart = true;
    bindMounts.nextcloud.hostPath =
      config.roos.container-host.guestMounts.nextcloud.hostPath;
    bindMounts.nextcloud.mountPoint = "/var/lib/nextcloud";
    bindMounts.nextcloud.isReadOnly = false;
    bindMounts."/run/secrets/services/nextcloud" = {};
    config = {
      networking.firewall.allowedTCPPorts = [ 80 ];
      networking.firewall.extraCommands = ''
        ip6tables -I nixos-fw -s fe80::/64 -p udp -m udp --dport 5355 -j ACCEPT
      '';
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];

      networking.nameservers = config.roos.container-host.nameservers;
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      systemd.services.systemd-networkd-wait-online = lib.mkForce {};

      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.nextcloud = {
        enable = true;
        home = "/var/lib/nextcloud";
        https = true;
        hostName = "nextcloud.orbstheorem.ch";
        maxUploadSize = "50G";
        enableImagemagick = true;
        package = pkgs.nextcloud24;
        autoUpdateApps.enable = true;
        config.adminuser = secrets.nextcloud.adminuser;
        config.adminpassFile = fsec."services/nextcloud/adminpass".path;
        config.dbuser = secrets.nextcloud.dbuser;
        config.dbpassFile = fsec."services/nextcloud/dbpass".path;
        config.dbtype = "pgsql";
        config.dbport = "5432";
        config.dbhost = "databases";
        config.defaultPhoneRegion = "CH";
        config.overwriteProtocol = "https";
      };
      users.users.nextcloud.uid = 999;
      users.groups.nextcloud.gid = 999;
      system.stateVersion = "22.11";
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.7/24";
    hostBridge = "orion";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 42080; containerPort = 80; protocol = "tcp"; }
      { hostPort = 26224; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.nextcloud = {
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
  roos.container-host.guestMounts.nextcloud = {};

  sops.secrets = let
    secretCfg = {
      restartUnits = [ "container@nextcloud.service" ];
      # We cannot set the required owner and group since the target values don't
      # exist in the host configuration, thus failing the activation script.
    };
  in {
    "services/nextcloud/adminpass" = secretCfg;
    "services/nextcloud/dbpass" = secretCfg;
  };

  system.activationScripts.secretsForNextcloud = let
    o = toString config.containers.nextcloud.config.users.users.nextcloud.uid;
    g = toString config.containers.nextcloud.config.users.groups.nextcloud.gid;
  in lib.stringAfter ["setupSecrets"] ''
    chown ${o}:${g} "${fsec."services/nextcloud/adminpass".path}"
    chown ${o}:${g} "${fsec."services/nextcloud/dbpass".path}"
  '';
}
