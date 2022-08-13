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
      description = "Template systemd unit to be triggered upon udev updates.";
      internal = true;
      type = types.str;
    };

    options.ifaces = mkOption {
      description = "interfaces part of this network";
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options.udevRegistration = mkOption {
          description = "Whether to add or remove iface upon udev updates.";
          default = true;
          type = types.bool;
        };
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
          description = "Systemd unit to be triggered upon udev updates.";
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
        unload = [
          "ip6tables -w -F ${cfg.in6-chain} 2> /dev/null || true"
          "ip6tables -w -X ${cfg.in6-chain} 2> /dev/null || true"
        ] ++ forEach (attrValues cfg.ifaces)
          (i: "ip6tables -w -D INPUT -i ${i.name} -j ${i.inChain} 2> /dev/null || true")
        ++ (flip concatMap) (attrValues cfg.ifaces) (i: [
          "ip6tables -w -F ${i.inChain} 2> /dev/null || true"
          "ip6tables -w -X ${i.inChain} 2> /dev/null || true"
        ]);
        policies = forEach cfg.in6-rules
          (r: "ip6tables -w -A ${cfg.in6-chain} ${r}")
        ++ forEach (attrValues cfg.ifaces)
          (i: "ip6tables -w -I INPUT -i ${i.name} -j ${i.inChain}")
        ;
      };
      ifaceRules = {
        inChains = "in-dev-${dev}";
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

  realiseUdevPkg = _: cfg: with lib; let
    udevIfaces = filter (i: i.udevRegistration) (attrValues cfg.ifaces);
    ifaceHooks = forEach udevIfaces (i: {
      match."ENV{INTERFACE}" = "${i.name}";
      match."SUBSYSTEM" = "net";
      make."RUN" = {
        operator = "+=";
        value = "${pkgs.systemd}/bin/systemd-cat ${pkgs.systemd}/bin/systemctl --no-block start ${i.trigger}";
      };
    });
  in pkgs.writeTextFile {
    name = "fw-net-${cfg.name}-udev-rules";
    destination = "/etc/udev/rules.d/150-fw-net-${cfg.name}.rules";
    text = ''
      # Update firewall rules upon network events
      ${concatMapStringsSep "\n" config.lib.udev.renderRule ifaceHooks}
    '';
  };

  realiseNetworkServices = _: cfg: with lib; {
    "${cfg.trigger}" = {
      description = "Template systemd unit to be triggered upon udev updates.";
      serviceConfig.ExecStartPre = "${pkgs.systemd}/bin/udevadm settle";
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

  watchIfaceScript = with lib; let
  in pkgs.writeShellScript "watch-iface-addr-changes" ''
    exec ${pkgs.iproute2}/bin/ip monitor addr \
      | ${pkgs.gawk}/bin/awk -F':' '$2!=""{print $2; fflush()}' \
      | ${pkgs.gawk}/bin/awk '{print $1; fflush()}' \
      | ${pkgs.findutils}/bin/xargs -Iiface udevadm trigger \
          --subsystem-match=net \
          --action=change /sys/class/net/iface
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
    services.udev.packages = lib.mapAttrsToList realiseUdevPkg cfg.networks;
    systemd.services = lib.mkMerge ([{
      "monitor-iface-addr-change@" = {
        description = "Watch for address changes on the specified interface";
        serviceConfig.ExecStart = "${watchIfaceScript} %i";
        serviceConfig.Type = "exec";
      };
      "firewall" = {
        wants = lib.forEach allIfaces
          (i: "monitor-iface-addr-change@${i}.service");
        serviceConfig.ExecStartPost =
          pkgs.writeShellScript "trigger-udev-in-all-ifaces" ''
            for if in /sys/class/net/*; do
              udevadm trigger --subsystem-match=net --action=change $if
            done
          '';
      };
    }] ++ lib.mapAttrsToList realiseNetworkServices cfg.networks);
  };
}
