{ config, options, pkgs, lib, ... }: with lib;
let
  cfg = config.roos.wireguard-new;
  hostname = config.networking.hostName;

  nixosIfaceOpts =
    options.networking.interfaces.type.functor.wrapped.getSubOptions [];

  networkHostOpts = { host, ... }: {
    options.ipv4 = nixosIfaceOpts.ipv4.addresses;
    options.ipv6 = nixosIfaceOpts.ipv6.addresses;
    options.addr = mkOption {
      type = with types; nullOr str;
    };
    options.keys.public = mkOption {
      type = types.str;
    };
    options.keys.private = mkOption {
      type = with types; nullOr str;
    };
    options.peeringport =
      let wgIfaceType = options.networking.wireguard.interfaces.type;
          wgIfaceOpts = (wgIfaceType.functor.wrapped.getSubOptions []);
      in wgIfaceOpts.listenPort // {
        description = ''
          Port this host will use connect to every other node in the network.
        '';
      };
  };

  wgIfaceOpts = { config, ... }: {
    options.network = mkOption {
      default = {};
      example = {
        h1 = {
          ipv4 = [ { address = "192.168.0.1"; prefixLength = 24; } ];
          addr = "demo.wireguard.io:12913";
          peeringport = 48100;
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
      let getpeeringports = c: mapAttrsToList (_: p: p.peeringport) c.network;
      in unique (flatten (mapAttrsToList (_: getpeeringports) cfg));
    networking.firewall.trustedInterfaces =
      let genIfaces = iface-base: { network }:
            mapAttrsToList (peer: _: "${iface-base}-${peer}") network;
      in flatten (mapAttrsToList genIfaces cfg);
    networking.wireguard.interfaces =
      let hostAddrs = h: with h; map addrToZoneStr (ipv4 ++ ipv6);
          netAddrs = net: flatten (forEach (attrValues net) hostAddrs);
          genIfaces = iface-base: { network }: let net = network; in
            mapAttrsToList (peer: { peeringport, ... }:
              nameValuePair "${iface-base}-${peer}" {
                listenPort = peeringport;
                ips = hostAddrs network."${hostname}";
                privateKey = net."${hostname}".keys.private;
                allowedIPsAsRoutes = false;
                peers = [{
                  endpoint =
                    let port = net."${hostname}".peeringport;
                    in net."${peer}".addr + ":" + (toString port);
                  allowedIPs = netAddrs net;
                  persistentKeepalive = 30;
                  publicKey = net."${peer}".keys.public;
                }];
              }) (filterAttrs (n: _: n != hostname) net);
      in listToAttrs (flatten (mapAttrsToList genIfaces cfg));
  };
}
