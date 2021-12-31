{ config, lib, options, ... }: let
  nixosIfaceOpts =
    options.networking.interfaces.type.functor.wrapped.getSubOptions [];
  cfg = config.roos.container-host;
in {
  options.roos.container-host = with lib; {
    enable = mkEnableOption ''
      Consolidate this machine as a container host.

      A `containerHostConfig` argument is added to the module call scope.
      Containers can use this to better integrate their configuration with
      the host.
    '';

    nameservers = mkOption {
      description = "Nameservers to be used by containers.";
      type = with types; listOf str;
      default = [ "1.1.1.1" ];
    };

    iface.name = mkOption {
      description = "Bridge interface where containers communicate to.";
      type = with types; nullOr string;
      default = "containers";
    };

    # FIXME: I would rather copy the whole ipv* option...
    iface.ipv4.addresses = nixosIfaceOpts.ipv4.addresses // {
      default = [{ address = "10.231.136.1"; prefixLength = 24; }];
    };
    iface.ipv6.addresses = nixosIfaceOpts.ipv6.addresses;
  };

  imports = let
    impl = {
      _module.args.containerHostConfig = {
        inherit (cfg) nameservers;
      };
      networking = lib.mkIf (cfg.iface.name != null) {
        bridges."${cfg.iface.name}".interfaces = [];
        interfaces."${cfg.iface.name}" = {
          inherit (cfg.iface) ipv4 ipv6;
        };
        nat.internalInterfaces = [ cfg.iface.name ];
      };
      # TODO: Systematic firewall hardening...
    };
  in [({ ... }: lib.mkIf cfg.enable impl)];
}
