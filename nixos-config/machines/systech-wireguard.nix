{ lib }:

let
  secrets = import ../secrets.nix { inherit lib; };
  networkMap = {
    Azulejo = ["10.13.234.1/16" "fd00:726f:6f73:234::/64"];
    Dellingr = ["10.13.95.1/16" "fd00:726f:6f73:95::/64"];
    Heimdaalr = ["10.13.1.1/16" "fd00:726f:6f73:1::/64"];
    Heisenberg = ["10.13.46.1/16" "fd00:726f:6f73:46::/64"];
    Hellendaal = ["10.13.5.1/16" "fd00:726f:6f73:5::/64"];
    Lappie = ["10.13.235.1/16" "fd00:726f:6f73:235::/64"];
    Triglav = ["10.13.13.1/16" "fd00:726f:6f73:13::/64"];
  };
  networkEndpoints = {
    Dellingr = "95.183.51.23:61573";
    Heimdaalr = "5.2.67.130:61573";
    Heisenberg = "46.101.112.218:61573";
    Hellendaal = "5.2.74.181:61573";
  };
  mkPeer = host: (let network = builtins.getAttr host networkMap; in {
      publicKey = (builtins.getAttr host secrets.machines).wireguardKeys.public;
      allowedIPs = network;
    }) //
    (if (!builtins.hasAttr host networkEndpoints) then {} else {
      endpoint = builtins.getAttr host networkEndpoints;
      persistentKeepalive = 1;
    });
in { hostname }: if !secrets.secretsAvailable then {} else {
  ips = builtins.getAttr hostname networkMap;
  listenPort = 61573;
  privateKey = (builtins.getAttr hostname secrets.machines).wireguardKeys.private;
  peers = map mkPeer (lib.attrNames networkMap);
  allowedIPsAsRoutes = false;
}
