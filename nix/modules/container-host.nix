{ config, lib, pkgs, options, ... }: let
  nixosIfaceOpts =
    options.networking.interfaces.type.functor.wrapped.getSubOptions [];
  removeCIDR = with lib; str: head (splitString "/" str);

  cfg = config.roos.container-host;

  containerFwOpts = { name, config, ... }: with lib; {
    options.allowInternet = mkOption {
      description = "Whether the container can connect to any internet address";
      default = true;
      type = types.bool;
    };

    options.allowLinkLocal = mkOption {
      description = "Whether to allow IPv6 link-local with the container";
      default = true;
      type = types.bool;
    };

    options.in-rules = mkOption {
      description = ''
        iptables rule specifications for traffic coming from the container into
        the host.
        These rules MUST be valid on both ipv4 and ipv6.

        Filters packages with the container host as destination.
      '';
      default = [];
      type = with types; listOf str;
      example = literalExpression ''[
        "-p udp -m udp --dport 53 -j ACCEPT"
      ];'';
    };

    options.ipv6.in-rules = mkOption {
      description = ''
        iptables rule specifications for traffic coming from the container into
        the host on ipv6.

        Filters packages with the container host as destination.
      '';
      default = [];
      type = with types; listOf str;
      example = literalExpression ''[
        "-p udp -m udp --dport 5355 -j ACCEPT"
      ];'';
    };

    options.ipv4.fwd-rules = mkOption {
      description = ''
        iptables rule specifications for the internal forward chain.

        Filters anything not being forwarded through
        `config.networking.nat.externalInterface`.
      '';
      default = [];
      type = with types; listOf str;
      example = literalExpression ''[
        "-d 10.13.255.101 -j ACCEPT"
      ];'';
    };

    options.ipv4.addrs = mkOption {
      description = ''
        IPv4 addresses corresponding to this container.

        This addresses will be used to hook the firewall rules.
      '';
      default = let
        v = config.containers."${name}".localAddress or null;
      in optional (v != null) (removeCIDR v);
      defaultText = literalExpression
        ''[ config.containers."''${name}".localAddress ]'';
      example = literalExpression ''[ "10.231.136.100" ];'';
      type = with types; nullOr (listOf str);
    };

    config = mkIf config.allowLinkLocal {
      ipv6.in-rules = [
        "-d fe80::/10 -j ACCEPT"
      ];
    };
  };

  nameAndFwCfgToRules = name: fwCfg: with lib; let
    inChain = "in-from-${name}";
    fwdChain = "fwd-from-${name}";
    externalIface = config.networking.nat.externalInterface;
  in {
    unload = [
    ] ++ forEach fwCfg.ipv4.addrs
      (a: "iptables -D INPUT -s ${a}/32 -j ${inChain} 2>/dev/null || true")
    ++ [
      "ip46tables -F ${inChain} 2> /dev/null || true"
      "ip46tables -X ${inChain} 2> /dev/null || true"
    ] ++ forEach fwCfg.ipv4.addrs
      (a: "iptables -D FORWARD -s ${a}/32 -j ${fwdChain} 2>/dev/null || true")
     ++ [
      "ip46tables -F ${fwdChain} 2> /dev/null || true"
      "ip46tables -X ${fwdChain} 2> /dev/null || true"
    ];

    create = [
      "ip46tables -N ${inChain}"
      "ip46tables -N ${fwdChain}"
    ];

    policies =
      optional fwCfg.allowInternet
        "ip46tables -A ${fwdChain} -o ${externalIface} -j ACCEPT"
      # IPv6-only in rules
      ++ forEach fwCfg.ipv6.in-rules
        (r: "ip6tables -A ${inChain} ${r}")
      # IPv4-only forward rules
      ++ forEach fwCfg.ipv4.fwd-rules
        (r: "iptables -A ${fwdChain} ${r}")
      # Input rules
      ++ forEach fwCfg.in-rules
        (r: "ip46tables -A ${inChain} ${r}")
      ;

    onFailure = [
      "ip46tables -A ${inChain} -j LOG --log-prefix 'Drop con from ${name} ' --log-level 6"
      "ip46tables -A ${inChain} -j DROP"
      "ip46tables -A ${fwdChain} -j LOG --log-prefix 'Drop fwd from ${name} ' --log-level 6"
      "ip46tables -A ${fwdChain} -j DROP"
    ];

    install = forEach fwCfg.ipv4.addrs
      (a: "iptables -I INPUT -s ${a}/32 -j ${inChain}")
    ++ forEach fwCfg.ipv4.addrs
      (a: "iptables -I FORWARD -s ${a}/32 -j ${fwdChain}")
    ;
  };

  guestMountOpts = { name, ... }: with lib; {
    options.hostPath = mkOption {
      description = "Path to this guest mount in the host.";
      default = "${cfg.hostDataDir}/${name}";
      readOnly = true;
    };
  };

in {
  options.roos.container-host = with lib; {
    enable = mkEnableOption "Consolidate this machine as a container host.";

    nameservers = mkOption {
      description = "Nameservers to be used by containers.";
      type = with types; listOf str;
      default = [ "1.1.1.1" ];
    };

    hostDataDir = mkOption {
      description = "Directory where to store data from containers.";
      type = types.str;
    };

    guestMounts = mkOption {
      description = "Mount volumes used by containers.";
      default = {};
      type = with types; let
        asAttrset = arg: if isList arg then genAttrs arg (_: {}) else arg;
      in coercedTo (listOf str) asAttrset (attrsOf (submodule guestMountOpts));
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

    firewall = mkOption {
      default = {};
      type = with types; attrsOf (submodule containerFwOpts);
      description = ''
        Description of firewall hardening to apply to each container.
      '';
    };
  };

  config = with lib; mkIf cfg.enable (mkMerge [{
    networking = mkIf (cfg.iface.name != null) {
      bridges."${cfg.iface.name}".interfaces = [];
      interfaces."${cfg.iface.name}" = {
        inherit (cfg.iface) ipv4 ipv6;
      };
      nat.internalInterfaces = [ cfg.iface.name ];

      firewall.extraCommands = let
        rules = mapAttrs nameAndFwCfgToRules cfg.firewall;
      in optionalString (cfg.firewall != {}) ''
        # Disengage, flush are delete helper chains.
        ${concatStringsSep "\n" (concatMap (a: a.unload) (attrValues rules))}

        # Create helper chains for each container.
        ${concatStringsSep "\n" (concatMap (a: a.create) (attrValues rules))}

        # Container chains customizations
        ${concatStringsSep "\n" (concatMap (a: a.policies) (attrValues rules))}

        # Log policy failures.
        ${concatStringsSep "\n" (concatMap (a: a.onFailure) (attrValues rules))}

        # Engage helper chains.
        ${concatStringsSep "\n" (concatMap (a: a.install) (attrValues rules))}
      '';
    };
  }

  (mkIf (cfg.guestMounts != {}) {
    systemd.services."container-host-volumes" = let
      hostPaths = mapAttrsToList (_: c: c.hostPath) cfg.guestMounts;
    in {
      serviceConfig.ExecStart = pkgs.writeShellScript "prepare-container-paths" (
        concatMapStringsSep "\n" (p: ''
          if ! [ -e "${p}" ]; then
            mkdir -p "$(dirname "${p}")"
            ${pkgs.btrfs-progs}/bin/btrfs subvolume create "${p}"
          fi
        '') ([ "${cfg.hostDataDir}/snapshots" ] ++ hostPaths)
      );
      serviceConfig.RemainAfterExit = true;
      wantedBy = [ "default.target" ];
    };

    roos.btrbk.config.volumes."${cfg.hostDataDir}" = let
      toRelative = path: removePrefix "${cfg.hostDataDir}/" path;
    in {
      subvolumes = mapAttrsToList (_: c: toRelative c.hostPath) cfg.guestMounts;
      snapshot_dir = "snapshots";
      snapshot_preserve = mkDefault "6h 7d 4w 6m";
      snapshot_preserve_min = mkDefault "1h";
    };
  })

  (mkIf (cfg.guestMounts != {}) {
    systemd.services = mapAttrs' (n: v: nameValuePair "container@${n}" {
      requires = [ "container-host-volumes.service" ];
      after = [ "container-host-volumes.service" ];
    }) config.containers;
  })]);
}
