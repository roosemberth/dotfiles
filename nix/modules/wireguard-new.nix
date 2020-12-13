{ config, options, pkgs, lib, ... }: with lib;
let
  cfg = config.roos.wireguard-new;
  hostname = config.networking.hostName;

  nixosIfaceOpts =
    options.networking.interfaces.type.functor.wrapped.getSubOptions [];

  networkHostOpts = { host, ... }: {
    options.ipv4 = nixosIfaceOpts.ipv4.addresses;
    options.ipv6 = nixosIfaceOpts.ipv6.addresses;
    options.endpoint = mkOption {
      type = with types; nullOr str;
    };
    options.keys.public = mkOption {
      type = types.str;
    };
    options.keys.private = mkOption {
      type = with types; nullOr str;
    };
  };

  wgIfaceOpts = { config, ... }: {
    options.listenPort =
      let wgIfaceType = options.networking.wireguard.interfaces.type;
          wgIfaceOpts = (wgIfaceType.functor.wrapped.getSubOptions []);
      in wgIfaceOpts.listenPort;
    options.network = mkOption {
      default = {};
      example = {
        h1 = {
          ipv4 = [ { address = "192.168.0.1"; prefixLength = 24; } ];
          endpoint = "demo.wireguard.io:12913";
        };
        h2.ipv4 = [ { address = "192.168.0.2"; prefixLength = 24; } ];
      };
      description = ''
        A description of the network this interface is a member of.
        The attribute correspoinding to the hostname will be used to configure
        the specified interface.
      '';
      type = with types; attrsOf (submodule networkHostOpts);
    };
    config.listenPort =
      let msg = "A listenPort or an endpoint in the network is required";
          endpoint = assert (assertMsg (hasAttr hostname config.network) msg);
            config.network.${hostname}.endpoint;
      in mkDefault (toInt (head (tail (strings.splitString ":" endpoint))));

  };

  addrToZoneStr =
    { address, prefixLength }: "${address}/${toString prefixLength}";
in {
  options.roos.wireguard-new = mkOption {
    default = {};
    description = ''
      Per-interface wireguard configuration.
    '';
    type = with types; attrsOf (submodule wgIfaceOpts);
  };

  config = mkIf (cfg != {}) {
    networking.firewall.allowedUDPPorts =
      mapAttrsToList (_: { listenPort, ... }: listenPort) cfg;
    networking.firewall.trustedInterfaces = attrNames cfg;
    networking.wireguard.interfaces = mapAttrs (_: { network, listenPort }: {
      inherit listenPort;
      ips = map addrToZoneStr (with network."${hostname}"; ipv4 ++ ipv6);
      privateKey = network."${hostname}".keys.private;
      peers = flip mapAttrsToList network (_: hostcfg: {
        endpoint = hostcfg.endpoint;
        allowedIPs = map addrToZoneStr (with hostcfg; ipv4 ++ ipv6);
        persistentKeepalive = 30;
        publicKey = hostcfg.keys.public;
      });
    }) cfg;
  };
}
