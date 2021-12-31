{ config, pkgs, secrets, containerHostConfig, ... }: let
  hostDataDirBase = "/mnt/cabinet/minerva-data";
in {
  containers.orion = {
    autoStart = true;
    bindMounts.orion.hostPath = "${hostDataDirBase}/orion";
    bindMounts.orion.mountPoint = "/persisted";
    bindMounts.orion.isReadOnly = false;
    config = {
      time.timeZone = config.time.timeZone;  # Inherit timezone config.
      networking.firewall.allowedTCPPorts = [ 8123 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = containerHostConfig.nameservers;
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.home-assistant = {
        enable = true;
        config = {
          image = {};
          person = {};
          cloud = {};
          onboarding = {};
          frontend = {};
          safe_mode = {};
          met = {};
          tradfri = {};
          nanoleaf = {};
          http.use_x_forwarded_for = true;
          http.trusted_proxies = [ "10.13.255.101" ];
        };
        configDir = "/persisted/hass";
        openFirewall = true;
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.8/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 48080; containerPort = 8123; protocol = "tcp"; }
    ];
  };

  networking.firewall.extraCommands = let
    exitIface = config.networking.nat.externalInterface;
    cidrContainer = "10.231.136.8/32";
    cidrRevProxy = "10.13.255.101/32";
  in ''
    # Disengage, flush are delete helper chains. TODO: IPv6
    iptables -w -D INPUT -s ${cidrContainer} \
      -j in-from-orion 2> /dev/null || true
    ip46tables -w -F in-from-orion 2> /dev/null || true
    ip46tables -w -X in-from-orion 2> /dev/null || true
    iptables -w -D FORWARD -s ${cidrContainer} \
      -j fwd-from-orion 2> /dev/null || true
    ip46tables -w -F fwd-from-orion 2> /dev/null || true
    ip46tables -w -X fwd-from-orion 2> /dev/null || true

    # Create helper chains.
    ip46tables -w -N in-from-orion
    ip46tables -w -N fwd-from-orion

    # Allow DNS
    ip46tables -w -A in-from-orion -p tcp -m tcp --dport 53 -j ACCEPT
    ip46tables -w -A in-from-orion -p udp -m udp --dport 53 -j ACCEPT

    # Public internet.
    ip46tables -A fwd-from-orion -o ${exitIface} -j ACCEPT
    iptables -A fwd-from-orion -d ${cidrRevProxy} -j ACCEPT

    # Log policy failures.
    ip46tables -A in-from-orion -j LOG \
      --log-prefix "Drop connection from Orion" --log-level 6
    ip46tables -A in-from-orion -j DROP
    ip46tables -A fwd-from-orion -j LOG \
      --log-prefix "Drop forward from Orion" --log-level 6
    ip46tables -A fwd-from-orion -j DROP

    # Engage helper chains. TODO: IPv6
    iptables -w -I INPUT -s ${cidrContainer} -j in-from-orion
    iptables -w -I FORWARD -s ${cidrContainer} -j fwd-from-orion
  '';

  systemd.services.orion-paths = {
    description = "Prepare paths used by home automation services.";
    requiredBy = [ "container@orion.service" ];
    before = [ "container@orion.service" ];
    path = with pkgs; [
      btrfs-progs
      e2fsprogs
      gawk
      utillinux
    ];
    environment.TARGET = "${hostDataDirBase}/orion";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
      in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
    };
  };
}
