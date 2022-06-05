{ config, lib, pkgs, secrets, ... }: let
  removeCIDR = with lib; str: head (splitString "/" str);
in {
  containers.named = {
    autoStart = true;
    config.nixpkgs.overlays =
      [(_:_: { inherit (pkgs) prometheus-bind-exporter; })];
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
      forwarders = [  # OpenNIC Servers (dns.opennic.glue)
        "2001:41d0:700:1174::"                  # ns1.de      Limburg
        "2001:4ba0:ffa4:1ce::"                  # ns22.de     Duesseldoft
        "2a01:4f9:4b:39ea::301"                 # ns4.fi      Helsinki
        "2a03:f80:30:192:71:166:92:1"           # ns1.esy.gr  Thessaloniki
        "2a0d:2146:2404::1069"                  # ns1.nl      Eygelshoven
      ];
      listenOn = map removeCIDR [ secrets.network.zkx.Minerva.host4 ];
      listenOnIpv6 = map removeCIDR [ secrets.network.zkx.Minerva.host6 ];
      zones = secrets.network.allDnsZones;
    };
    config.services.prometheus.exporters.bind.enable = true;
    config.services.prometheus.exporters.bind.bindGroups =
      [ "server" "view" "tasks" ];
    ephemeral = false; # TODO: isolate cache as a spool directory...
  };

  networking.search = with secrets.network.zksDNS; [ search ];
  networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;
}
