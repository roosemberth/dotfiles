{ config, lib, pkgs, networks, ... }: let
  removeCIDR = with lib; str: head (splitString "/" str);
  fsec = config.sops.secrets;
in {
  containers.named = {
    autoStart = true;
    bindMounts."/run/secrets/services/dns" = {};
    config.nixpkgs.overlays =
      [(_:_: { inherit (pkgs) prometheus-bind-exporter; })];

    config.networking.useHostResolvConf = false;
    config.networking.useNetworkd = true;
    config.systemd.services.systemd-networkd-wait-online = lib.mkForce {};

    config.services.bind = {
      enable = true;
      cacheNetworks =
        [ "127.0.0.0/8"
          "::1/128"
          "10.13.255.0/24"
          "fd00:726f:6f73::/48"
          "10.231.136.4" # Exceptionally resolve for the matrix container...
          # The amount of queries made by matrix breaks systemd-resolved...
        ];
      extraConfig = ''
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };
      '';
      forwarders = [  # Should use OpenNIC Servers (dns.opennic.glue)
        # Use init7 at the moment...
        "2001:1620:2777:1::10"
        "2001:1620:2777:2::20"
        "77.109.128.2"
        "213.144.129.20"
      ];
      listenOn = [ networks.zkx.dns.v4 ];
      listenOnIpv6 = [ networks.zkx.dns.v6 ];
      zones = [{
        name = "zkx.ch";
        master = true;
        file = fsec."services/dns/zones/zkx.ch".path;
      }];
    };
    config.services.prometheus.exporters.bind.enable = true;
    config.services.prometheus.exporters.bind.bindGroups =
      [ "server" "view" "tasks" ];
    config.system.stateVersion = "22.05";
    config.users.users.named.uid = 999;
    config.users.groups.named.gid = 999;
    ephemeral = false; # TODO: isolate cache as a spool directory...
  };

  # We cannot set the required owner and group since the target values don't
  # exist in the host configuration, thus failing the activation script.
  sops.secrets."services/dns/zones/zkx.ch".restartUnits =
    [ "container@named.service" ];
  system.activationScripts.secretsForNamed = let
    o = toString config.containers.named.config.users.users.named.uid;
    g = toString config.containers.named.config.users.groups.named.gid;
  in lib.stringAfter ["setupSecrets"] ''
    chown ${o}:${g} "${fsec."services/dns/zones/zkx.ch".path}"
  '';

  networking.nameservers = with networks.zkx.dns; [v6 v4];
}
