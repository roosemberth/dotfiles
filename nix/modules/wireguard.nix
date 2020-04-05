{ config, pkgs, lib, secrets, ... }: with lib;
let
  cfg = config.roos.wireguard;
  cidrToHost = address:
    builtins.replaceStrings ["/24" "/120"] ["/32" "/128"] address;
  netsForHost = host:
    flatten (attrValues (attrByPath [host] {} secrets.network.foreignNetworks));
  mkWireguardPeer = host: endpoint: with secrets; with network; {
    inherit endpoint;
    allowedIPs = map cidrToHost hostNetworks.${host} ++ netsForHost host;
    persistentKeepalive = 30;
    publicKey = (forHost host).keys.wireguard.public;
  };
  wireguardPeers =
    mapAttrs mkWireguardPeer secrets.network.publicWireguardEndpoints;
in {
  options.roos.wireguard = {
    enable = mkEnableOption "Enable wireguard.";

    interface = mkOption {
      type = types.str;
      default = "Bifrost";
      description = ''
        Name of the interface where to configure wireguard.
      '';
    };

    gwServer = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        If specified, such peer will be used to connect to the network.
        No other peers will be added to the VPN configuration.
        If null, all peers will be added with their respective networks
        as defined in secrets.network.hostNetworks.
      '';
    };
  };

  config = let
    hostname = config.networking.hostName;
    endpoints = secrets.network.publicWireguardEndpoints;
    listenPort = if !hasAttr hostname endpoints then 61573
      else head (tail (strings.splitString ":" endpoints.${hostname}));
    gwServerAssert = assertMsg (hasAttr cfg.gwServer endpoints)
                       "The specified gwServer is unkonwn.";
  in mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ listenPort ];
    networking.firewall.trustedInterfaces = [ cfg.interface ];
    networking.wireguard.interfaces.${cfg.interface} =
      if !secrets.secretsAvailable then {} else {
        inherit listenPort;
        ips = secrets.network.hostNetworks.${hostname};
        privateKey = (secrets.forHost hostname).keys.wireguard.private;
        peers = if cfg.gwServer == null then attrValues wireguardPeers
          else assert gwServerAssert; [(wireguardPeers.${cfg.gwServer} // {
            allowedIPs = flatten (attrValues secrets.network.hostNetworks);
          })];
        allowedIPsAsRoutes = false;
      };

    security.sudo.extraConfig = ''
      %wheel ALL=(root) NOPASSWD: /run/current-system/sw/bin/wg
    '';
  };
}
