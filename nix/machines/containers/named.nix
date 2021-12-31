{ config, lib, pkgs, secrets, ... }: let
  removeCIDR = with lib; str: head (splitString "/" str);
in {
  containers.named = {
    autoStart = true;
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
      forwarders = [  # OpenNIC Servers
        "2a01:7e01::f03c:91ff:febc:322"         # ns2.he.de   Frankfurt
        "2a01:4f9:c010:6093::3485"              # ns2.fi      Helsinki
        "2001:bc8:32d7:308::201"                # ns3.fr      Paris
        "2a00:f826:8:1::254"                    # ns8.he.de   Frankfurt
        "2001:470:1f15:b80::53"                 # ns8.fr      Paris
        "2001:19f0:7402:d:5400:00ff:fe2a:7fb6"  # ns4.eng.gb  London
        "2a01:4f8:161:3441::1"                  # ns3.de      Frankfurt
        "2a00:f826:8:2::195"                    # ns31.de     Frankfurt
      ];
      listenOn = map removeCIDR [ secrets.network.zkx.Minerva.host4 ];
      listenOnIpv6 = map removeCIDR [ secrets.network.zkx.Minerva.host6 ];
      zones = secrets.network.allDnsZones;
    };
    ephemeral = false; # TODO: isolate cache as a spool directory...
  };

  networking.search = with secrets.network.zksDNS; [ search ];
  networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;
}
