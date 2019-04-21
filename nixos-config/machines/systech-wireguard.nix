{ lib }:

let
  secrets = import ../secrets.nix { inherit lib; };
  hostNetworks = secrets.network.hostNetworks;
  networkAddressToSingleAddress = address:
    builtins.replaceStrings ["/24" "/120"] ["/32" "/128"] address;
  mkWireguardPeer = host: endpoint: {
    inherit endpoint;
    allowedIPs = map networkAddressToSingleAddress hostNetworks.${host};
    persistentKeepalive = 30;
    publicKey = secrets.machines.${host}.wireguardKeys.public;
  };
  wireguardPeers = lib.mapAttrs mkWireguardPeer secrets.network.publicWireguardEndpoints;

in {
  inherit wireguardPeers mkWireguardPeer;
  mkWireguardCfgForHost = hostname: if !secrets.secretsAvailable then {} else {
    ips = hostNetworks.${hostname};
    listenPort = 61573;
    privateKey = secrets.machines.${hostname}.wireguardKeys.private;
    peers = lib.attrValues wireguardPeers;
    allowedIPsAsRoutes = false;
  };
}
