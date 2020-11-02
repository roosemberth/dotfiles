{ config, pkgs, lib, secrets, ... }: with lib;
let
  cfg = config.roos.wireguard;
  cidrToHost = address:
    builtins.replaceStrings ["/24" "/120"] ["/32" "/128"] address;
  mkWireguardPeer = host: endpoint: with secrets; with network; {
    inherit endpoint;
    allowedIPs = with zkx.${host}; map cidrToHost [host4 host6] ++ ipv4 ++ ipv6;
    persistentKeepalive = 30;
    publicKey = (forHost host).keys.wireguard.public;
  };
  bastions = mapAttrs mkWireguardPeer secrets.network.zkxBastions;
  allNetworkIPs = flatten (
    mapAttrsToList
      (_: p: with p; [host4 host6] ++ ipv4 ++ ipv6)
      secrets.network.zkx
  );
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
        as defined in secrets.network.zkx.
      '';
    };
  };

  config = let
    hostname = config.networking.hostName;
    endpoints = secrets.network.zkxBastions;
    listenPort = if !hasAttr hostname endpoints then 61573
      else head (tail (strings.splitString ":" endpoints.${hostname}));
    gwServerAssert = assertMsg (hasAttr cfg.gwServer endpoints)
                       "The specified bastion is unknown.";
  in mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ listenPort ];
    networking.firewall.trustedInterfaces = [ cfg.interface ];
    networking.wireguard.interfaces.${cfg.interface} = {
      inherit listenPort;
      ips = with secrets.network.zkx.${hostname}; [host4 host6];
      privateKey = (secrets.forHost hostname).keys.wireguard.private;
      peers = if cfg.gwServer == null then attrValues bastions
        else assert gwServerAssert; [(bastions.${cfg.gwServer} // {
          allowedIPs = allNetworkIPs;
        })];
      allowedIPsAsRoutes = false;
    };

    security.sudo.extraConfig = ''
      %wheel ALL=(root) NOPASSWD: /run/current-system/sw/bin/wg
    '';
  };
}
