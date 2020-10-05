{ config, pkgs, secrets, ... }:
{
  containers.named = {
    autoStart = true;
    config.services.bind = {
      enable = true;
      cacheNetworks =
        ["127.0.0.0/8" "::1/128"]
        ++ secrets.network.trustedNetworks.ipv4
        ++ secrets.network.trustedNetworks.ipv6;
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
      zones = secrets.network.allDnsZones;
    };
    forwardPorts = [
      {hostPort = 53; protocol = "tcp";}
      {hostPort = 53; protocol = "udp";}
    ];
  };

  networking.search = with secrets.network.zksDNS; [ search ];
  networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;
}
