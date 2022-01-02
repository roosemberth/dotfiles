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

  roos.container-host.firewall.orion = {
    in-rules = [ "-p udp -m udp --dport 53 -j ACCEPT" ];
    ipv4.fwd-rules = [ "-d 10.13.255.101/32 -j ACCEPT" ];
  };

  systemd.services."container@orion".unitConfig.ConditionPathIsDirectory =
    [ "${hostDataDirBase}/orion" ];
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
    unitConfig.ConditionPathIsDirectory = [ "${hostDataDirBase}/orion" ];
  };
}
