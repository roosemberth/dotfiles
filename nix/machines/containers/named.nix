{ config, lib, pkgs, secrets, networks, ... }: let
  removeCIDR = with lib; str: head (splitString "/" str);
in {
  containers.named = {
    autoStart = true;
    config.nixpkgs.overlays =
      [(_:_: { inherit (pkgs) prometheus-bind-exporter; })];

    config.networking.useHostResolvConf = false;
    config.networking.useNetworkd = true;
    config.systemd.services.systemd-networkd-wait-online = lib.mkForce {};

    config.services.bind = {
      enable = true;
      cacheNetworks =
        ["127.0.0.0/8" "::1/128"]
        ++ secrets.network.trustedNetworks.ipv4
        ++ secrets.network.trustedNetworks.ipv6
        ++ [
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
      listenOn = map removeCIDR
        [ networks.zkx.publicInternalAddresses.Minerva.v4 ];
      listenOnIpv6 = map removeCIDR
        [ networks.zkx.publicInternalAddresses.Minerva.v6 ];
      zones = secrets.network.allDnsZones;
    };
    config.services.prometheus.exporters.bind.enable = true;
    config.services.prometheus.exporters.bind.bindGroups =
      [ "server" "view" "tasks" ];
    config.system.stateVersion = "22.05";
    ephemeral = false; # TODO: isolate cache as a spool directory...
  };
  networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;
}
