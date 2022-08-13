{ config, pkgs, lib, ... }: let
  cfg = config.roos.firewall;

  networkOpts = { name, config, ... }: with lib; let
    net = config;
  in {
    options.name = mkOption {
      default = name;
      internal = true;
      type = types.str;
    };

    options.trigger = mkOption {
      default = "fw-reconfigure-net-${net.name}@";
      description = "Name of unit triggered upon changes in an interfaces.";
      internal = true;
      type = types.str;
    };

    options.ifaces = mkOption {
      description = "interfaces part of this network";
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options.name = mkOption {
          default = name;
          internal = true;
          type = types.str;
        };
        options.inChain = mkOption {
          default = "dev-${name}-in";
          internal = true;
          type = types.str;
        };
        options.trigger = mkOption {
          default = "${net.trigger}${name}.service";
          description = "Systemd unit to be triggered upon interface changes.";
          internal = true;
          type = types.str;
        };
      }));
    };

    options.in6-rules = mkOption {
      description = ''
        iptables ipv6 rule specifications for traffic coming from this network.
      '';
      default = [];
      type = with types; listOf str;
      example = literalExpression ''[
        "-p udp -m udp --dport 53 -j ACCEPT"
      ];'';
    };

    options.in6-chain = mkOption {
      default = "in6-net-${net.name}";
      internal = true;
      type = types.str;
    };
  };

  realiseNetwork = _: cfg: with lib; {
    firewall.extraCommands = let
      networkRules = rec {
        create = [
          "ip6tables -w -N ${cfg.in6-chain}"
        ] ++ forEach (attrValues cfg.ifaces)
          (i: "ip6tables -w -N ${i.inChain}")
        ;
        unload = forEach (attrValues cfg.ifaces)
          (i: "ip6tables -w -D INPUT -i ${i.name} -j ${i.inChain} 2> /dev/null || true")
        ++ (flip concatMap) (attrValues cfg.ifaces) (i: [
          "ip6tables -w -F ${i.inChain} 2> /dev/null || true"
          "ip6tables -w -X ${i.inChain} 2> /dev/null || true"
        ]) ++ [
          "ip6tables -w -F ${cfg.in6-chain} 2> /dev/null || true"
          "ip6tables -w -X ${cfg.in6-chain} 2> /dev/null || true"
        ];
        policies = forEach cfg.in6-rules
          (r: "ip6tables -w -A ${cfg.in6-chain} ${r}")
        ++ forEach (attrValues cfg.ifaces)
          (i: "ip6tables -w -I INPUT -i ${i.name} -j ${i.inChain}")
        ;
      };
    in ''
      # Disengage, flush are delete chains.
      ${concatStringsSep "\n" networkRules.unload}

      # Create helper chains.
      ${concatStringsSep "\n" networkRules.create}

      # Apply policies to chains.
      ${concatStringsSep "\n" networkRules.policies}
    '';
  };

  realiseNetworkServices = _: cfg: with lib; {
    "${cfg.trigger}" = {
      description = "Template unit triggered upon changed in an interface.";
      serviceConfig.ExecStart = "${mkProbeNetworkScript cfg} %i";
      serviceConfig.Type = "exec";
    };
  };

  mkProbeNetworkScript = cfg: with lib; let
  in pkgs.writeShellScript "fw-reconfigure-device-for-net-${cfg.name}" ''
    IFACE=""
    case "$1" in
    ${concatMapStringsSep "\n" (i: ''
      (${i.name})
        IFACE="${i.name}"
        IFACE_INCHAIN="${i.inChain}"
        NET_IN6CHAIN="${cfg.in6-chain}"
        ;;'') (attrValues cfg.ifaces)}
    esac

    if [ -z "$IFACE" ]; then
      echo -n "This script should be called with an interface part of network "
      echo "${cfg.name}: ${escapeShellArgs (attrNames cfg.ifaces)}"
      exit 1
    fi

    echo "I received notice $IFACE was updated."

    ${pkgs.iptables}/bin/ip6tables -w -F "$IFACE_INCHAIN" 2> /dev/null || true
    ${pkgs.iproute2}/bin/ip --json addr show dev "$IFACE" \
      | ${pkgs.jq}/bin/jq -r '.[]
          |.addr_info[]
          |select(.family=="inet6")
          |"\(.local)/\(.prefixlen)"' \
      | (while read -r cidr; do
          ${pkgs.iptables}/bin/ip6tables -w -I "$IFACE_INCHAIN" \
            -s "$cidr" -j "$NET_IN6CHAIN"
         done)
  '';

  mkWatchIfaceScript = net: with lib; let
    ifaceRegex = concatStringsSep "|" (attrNames net.ifaces);
  in pkgs.writeShellScript "watch-iface-addr-changes" ''
    exec ${pkgs.iproute2}/bin/ip monitor addr \
      | ${pkgs.gawk}/bin/awk -F':' '$2!=""{print $2; fflush()}' \
      | ${pkgs.gawk}/bin/awk '$1~"${ifaceRegex}"{print $1; fflush()}' \
      | ${pkgs.findutils}/bin/xargs -Iiface ${pkgs.systemd}/bin/systemd-cat \
          ${pkgs.systemd}/bin/systemctl --no-block start ${net.trigger}iface
  '';

  allIfaces = with lib;
    unique (concatMap (n: attrNames n.ifaces) (attrValues cfg.networks));
in {
  options.roos.firewall = with lib; {
    networks = mkOption {
      description = "A network is a relation of interfaces and fw rules.";
      type = with types; attrsOf (submodule networkOpts);
      default = {};
    };
  };

  config = {
    networking = lib.mkMerge (lib.mapAttrsToList realiseNetwork cfg.networks);
    systemd.services = lib.mkMerge ([{
      "firewall" = with lib; {
        serviceConfig.ExecStartPost =
          pkgs.writeShellScript "trigger-fw-update-in-all-networks" ''
            # Triger an updates on every interface on every network
            ${concatMapStringsSep "\n" (i: ''
              ${pkgs.systemd}/bin/systemd-cat \
                ${pkgs.systemd}/bin/systemctl --no-block start ${i.trigger}
            '') (concatMap (n: attrValues n.ifaces) (attrValues cfg.networks))}
          '';
      };
    }] ++ lib.mapAttrsToList realiseNetworkServices cfg.networks
    ++ lib.mapAttrsToList (_: v: {
      "monitor-net-${v.name}-ifaces" = {
        description = "Monitor addr changes on interfaces on network ${v.name}";
        before = [ "firewall.service" ];
        wantedBy = [ "firewall.service" ];
        serviceConfig.ExecStart = "${mkWatchIfaceScript v} %i";
        serviceConfig.Type = "exec";
      };
    }) cfg.networks);
  };
}
