{ config, pkgs, lib, secrets, ... }: {
  containers.orion = {
    autoStart = true;
    bindMounts.ha-orion.hostPath =
      config.roos.container-host.guestMounts.ha-orion.hostPath;
    bindMounts.ha-orion.mountPoint = "/persisted";
    bindMounts.ha-orion.isReadOnly = false;
    config = {
      time.timeZone = config.time.timeZone;  # Inherit timezone config.
      networking.firewall.allowedTCPPorts = [ 8123 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];

      networking.nameservers = config.roos.container-host.nameservers;
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      systemd.services.systemd-networkd-wait-online = lib.mkForce {};

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
      system.stateVersion = "22.05";
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.8/24";
    hostBridge = "orion";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 48080; containerPort = 8123; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.orion = {
    in-rules = [ "-p udp -m udp --dport 53 -j ACCEPT" ];
    ipv4.fwd-rules = [ "-d 10.13.255.101/32 -j ACCEPT" ];
  };
  roos.container-host.guestMounts.ha-orion = {};
}
