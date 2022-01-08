{ config, pkgs, secrets, ... }: {
  containers.nextcloud = {
    autoStart = true;
    bindMounts.nextcloud.hostPath =
      config.roos.container-host.guestMounts.nextcloud.hostPath;
    bindMounts.nextcloud.mountPoint = "/var/lib/nextcloud";
    bindMounts.nextcloud.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 80 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = config.roos.container-host.nameservers;
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
        config.adminpassFile =
          "${pkgs.writeText "nap" secrets.nextcloud.adminpass}";
        config.dbuser = secrets.nextcloud.dbuser;
        config.dbpassFile = "${pkgs.writeText "ndp" secrets.nextcloud.dbpass}";
        config.dbtype = "pgsql";
        config.dbport = "5432";
        config.dbhost = "minerva.intranet.orbstheorem.ch";
        config.defaultPhoneRegion = "CH";
        config.overwriteProtocol = "https";
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
}
