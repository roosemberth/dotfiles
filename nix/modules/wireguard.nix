{ config, pkgs, lib, networks, ... }: with lib; let
  cfg = config.roos.wireguard;

  genPeerConfigScript = pkgs.writers.writeHaskell
    "config-wg-peers"
    { libraries = with pkgs.haskellPackages; [ yaml interpolate ]; }
    ''
      {-# LANGUAGE DeriveAnyClass #-}
      {-# LANGUAGE DeriveGeneric #-}
      {-# LANGUAGE LambdaCase #-}
      {-# LANGUAGE QuasiQuotes #-}
      {-# LANGUAGE RecordWildCards #-}

      import Data.List (intersperse)
      import Data.Map
      import Data.Maybe (catMaybes, fromMaybe)
      import Data.String.Interpolate
      import Data.Yaml
      import GHC.Generics
      import System.Environment (getArgs)
      import System.Exit (exitFailure)

      data Network = Network
        { public_keys :: Map String String
        , endpoints ::  Map String String
        , subnets :: Map String [String]
        } deriving (Generic, Show, Eq, FromJSON, ToJSON)

      data PeerConfig = PeerConfig
        { public_key :: String
        , keepalive :: Maybe String
        , allowedIps :: [String]
        , endpoint :: Maybe String
        } deriving (Show, Eq)

      networkToPeers :: Network -> [PeerConfig]
      networkToPeers Network{..} = uncurry toPeer <$> toList public_keys
        where toPeer host key = let
                  public_key = key
                  keepalive = Just "30"
                  allowedIps = fromMaybe [] (subnets !? host)
                  endpoint = endpoints !? host
                in PeerConfig{..}

      type InterfaceName = String

      setupCmd :: InterfaceName -> PeerConfig -> String
      setupCmd iface PeerConfig{..} =
        [i|${pkgs.wireguard-tools}/bin/wg set "#{iface}" peer "#{public_key}" #{unwords args} allowed-ips "#{ips allowedIps}"|]
        where ips = mconcat . intersperse ","
              arg name v = (\v -> [i|#{name} "#{v}"|]) <$> v
              args = catMaybes [arg "persistent-keepalive" keepalive, arg "endpoint" endpoint]

      main :: IO ()
      main = getArgs >>= \case
        (iface:cfgFile:_) -> do
          network <- decodeFileThrow cfgFile
          foldMap (putStrLn . setupCmd iface) (networkToPeers network)
        _ -> putStrLn "Arguments: <interface> /path/to/config.yaml" >> exitFailure
    '';

in {
  options.roos.wireguard = {
    enable = mkEnableOption "Enable wireguard network";

    interface = mkOption {
      type = types.str;
      default = "Bifrost";
      description = ''
        Name of the interface where to configure wireguard.
      '';
    };

    listenPort = mkOption {
      type = types.int;
      default = 61573;
      description = "Port where wireguard should listen to.";
    };

    network = mkOption {
      type = types.str;
      default = "bifrost";
      description = "Name of the secret containing the network description.";
    };

    network-secret-path = mkOption {
      description = "Path to the secret containing the network description";
      default = config.sops.secrets."networks/${cfg.network}".path;
      readOnly = true;
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ cfg.listenPort ];
    networking.firewall.trustedInterfaces = [ cfg.interface ];

    networking.wireguard.interfaces.${cfg.interface} = {
      inherit (cfg) listenPort;
      ips = with networks.zkx.publicInternalAddresses.${config.networking.hostName};
        [ v4 v6 ];
      privateKeyFile = config.sops.secrets."wireguard/private".path;
    };

    # Hook to the interface activation service
    systemd.services."setup-wireguard-${cfg.interface}-peers" = {
      description = "Configure wireguard peers for interface ${cfg.interface}";
      after = ["wireguard-${cfg.interface}.service"];
      bindsTo = ["wireguard-${cfg.interface}.service"];
      wantedBy = ["wireguard-${cfg.interface}.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "configure-wireguard-peers" ''
          ${genPeerConfigScript} ${cfg.interface} ${cfg.network-secret-path} \
            | ${pkgs.bash}/bin/bash -xs
        '';
      };
    };

    security.sudo.extraConfig = ''
      %wheel ALL=(root) NOPASSWD: /run/current-system/sw/bin/wg
    '';

    sops.secrets = {
      "wireguard/private".restartUnits = [ "wireguard-Bifrost.service" ];
      "networks/${cfg.network}" = {
        sopsFile = ../../secrets/per-role/network.yaml;
      };
    };
  };
}
