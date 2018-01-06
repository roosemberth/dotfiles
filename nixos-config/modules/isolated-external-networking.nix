# Roosembert Palacios - 2018
# Released under CC-BY-SA on 05.01.18

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.isolateExternalNetworking;
  mandatoryBlacklist = [ "lo" ];
in

{
  options = {
    networking.isolateExternalNetworking = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      nsname = mkOption {
        type = types.str;
        default = "Himinbjorg";
        description = "Name of the network namespace to be used to isolate external networking";
      };
      blacklist = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = literalExample "[ enp0s* lo ]";
        description = "Network interfaces never to be exported, note that lo as {up,br}-nsname are automatically blacklisted";
      };
      whitelist = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = literalExample "[ enp0s* wlp4s0 ]";
        description = "Network interfaces always to be exported";
      };
      dynamic = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to move interfaces not specified in the whitelist";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services."wpa_supplicant" = {
      after = [ "netns-upstream-nat@${cfg.nsname}.service" ];
      unitConfig.JoinsNamespaceOf = "netns@${cfg.nsname}.service";
      serviceConfig.PrivateNetwork = "yes";
    };

    systemd.services."network-manager" = let
      nmNetnsWrapper = pkgs.writeScript "nm-netns-wrapper" ''
        #!${pkgs.stdenv.shell} -e

        # Mounting sysfs ro tells network manager not to expect udev, which is not running in this namespace.
        ${pkgs.utillinux}/bin/mount -t sysfs nm-sysfs /sys -o ro
        exec ${pkgs.networkmanager}/sbin/NetworkManager --no-daemon
      '';
    in {
      after = [ "netns-upstream-nat@${cfg.nsname}.service" ];
      bindsTo = [ "netns-upstream-nat@${cfg.nsname}.service" ];
      unitConfig.JoinsNamespaceOf = "netns@${cfg.nsname}.service";
      serviceConfig.PrivateNetwork = "yes";
      serviceConfig.CapabilityBoundingSet="CAP_SYS_ADMIN";
      serviceConfig.ExecStart = [
        "" # override upstream default with an empty ExecStart
        nmNetnsWrapper
      ];
    };

    systemd.services."netns-upstream-nat@" = {
      description = "Use network namespace %I as upstream route.";
      # For some weird reason, this unit won't get restarted when netns@%i when using bindsTo
      #bindsTo = [ "netns@%i.service" ];
      requiredBy = [ "netns@%i.service" ];
      requires = [ "netns@%i.service" ];
      after = [ "netns@%i.service" ];

      unitConfig.StopWhenUnneeded = "true";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
      };

      environment = {
        NAMESPACE = "%i";
        DEVNAME_ASGARD = "up-%i"; # Called up since from asgard, this is upstream
        DEVNAME_BIFROST = "br-%i";
      };

      script = let
        setupExternalNetworking = pkgs.writeScript "setup-nat" ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s "$BIFROST_IP"/"$CIDR" -j MASQUERADE &>/dev/null || true

          ${pkgs.iproute}/bin/ip address add "$BIFROST_IP"/"$CIDR" dev "$DEVNAME_BIFROST"
          ${pkgs.iproute}/bin/ip link set "$DEVNAME_BIFROST" up

          ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s "$BIFROST_IP"/"$CIDR" -j MASQUERADE
          ${pkgs.coreutils}/bin/tee /proc/sys/net/ipv4/ip_forward <<< 1
        '';
      in ''
        # TODO: Dynamically figure out unused ips...
        export ASGARD_IP=169.254.1.2
        export BIFROST_IP=169.254.1.1
        export CIDR=30 # Network/Upstream/Downstream/Broadcast

        # If we were restarted for any reason, clean up
        ${pkgs.iproute}/bin/ip link del "$DEVNAME_ASGARD"  &>/dev/null || true
        ${pkgs.iproute}/bin/ip link del "$DEVNAME_BIFROST" &>/dev/null || true

        # Setup veth pair and local networking
        ${pkgs.iproute}/bin/ip link add "$DEVNAME_ASGARD" type veth peer name "$DEVNAME_BIFROST"
        ${pkgs.iproute}/bin/ip addr add "$ASGARD_IP"/"$CIDR" dev "$DEVNAME_ASGARD"
        ${pkgs.iproute}/bin/ip link set "$DEVNAME_BIFROST" netns "$NAMESPACE"
        ${pkgs.iproute}/bin/ip link set "$DEVNAME_ASGARD" up

        # Setup routing
        ${pkgs.iproute}/bin/ip route add default via "$BIFROST_IP"

        # Setup external networking
        ${pkgs.iproute}/bin/ip netns exec $NAMESPACE ${setupExternalNetworking}
      '';

      preStop = let
        clearNat = pkgs.writeScript "cleanup-nat" ''
          ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s "$BIFROST_IP"/"$CIDR" -j MASQUERADE || true
          ${pkgs.iproute}/bin/ip link del "$DEVNAME_BIFROST" || true
        '';
      in ''
        # Clear external networking
        ${pkgs.iproute}/bin/ip netns exec $NAMESPACE ${clearNat}

        # Remove external upstream default route
        ${pkgs.iproute}/bin/ip link del "$DEVNAME_ASGARD"  &>/dev/null || true
      '';
    };

    systemd.services."netns@" = let
    deleteIfExists = pkgs.writeScript "wipe-namespace-if-exists" ''
        if [ -z "$1" ]; then
            echo "BUG: Cannot cleanup namespace, please specify namespace as argument" >&2
            exit 1
        fi

        # Don't die on error
        set +e

        PIDS="$(${pkgs.iproute}/bin/ip netns pids $1)"
        if [ -n "$PIDS" ]; then
            echo "Asking processes inside $1 to exit"
            for pid in $PIDS; do
              kill -TERM $pid
            done
            for pid in $PIDS; do
              kill -INT $pid
            done
            for pid in $PIDS; do
              kill -QUIT $pid
            done

            PIDS="$(${pkgs.iproute}/bin/ip netns pids $1)"
            if [ -n "$PIDS" ]; then
                sleep 1 # They got 1 second to clear out!

                for pid in $PIDS; do
                  kill -KILL $pid
                done
            fi
        fi

        ${pkgs.iproute}/bin/ip netns del "$1"
        rm /var/run/netns/$1
    '';
    in {
      description = "Named network namespace %I";
      documentation = [ "https://github.com/systemd/systemd/issues/2741#issuecomment-336736214" ];
      before = [ "systemd-udevd.service" ];

      unitConfig.StopWhenUnneeded = "true";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        PrivateNetwork = "yes";
        PrivateTmp = "yes";

        # FIXME: Mount /sys on mnt namespace; systemd.exec(5):
        # If this is set to slave or private, any mounts created by spawned processes will be unmounted after the
        # completion of the current command line of ExecStartPre=, ExecStartPost=, ExecStart=, and ExecStopPost=.
        MountFlags = "slave";
      };

      environment.NAMESPACE = "%i";

      script = let
        publishPidNetNSs = pkgs.writeScript "bind-pid-netns-systemwide" ''
          [ -z "$1" ] && echo "Cannot find pid" >&2 && exit 1
          [ -z "$2" ] && echo "Cannot find NS" >&2 && exit 1

          ${deleteIfExists} "$2"

          ${pkgs.iproute}/bin/ip netns add "$2"
          # Drop the network namespace that ip netns just created
          ${pkgs.utillinux}/bin/umount /var/run/netns/"$2"
          # Re-use the same name for the network namespace that systemd put us in
          ${pkgs.utillinux}/bin/mount --bind /proc/$1/ns/net /var/run/netns/"$2"
        '';
      in ''
        if [ -z "$NAMESPACE" ] ; then
            echo "BUG: Cannot setup namespace. NAMESPACE variable not set!" >&2
            exit 1
        fi

        # Escape :D ; in pid 1 namespace (main):
        ${pkgs.utillinux}/bin/nsenter --all -t 1 ${publishPidNetNSs} "$$" "$NAMESPACE"
      '';

      preStop = "${deleteIfExists} $NAMESPACE";
    };

    services.udev.extraRules = let
        blacklistedInterfaces = (cfg.blacklist ++ mandatoryBlacklist ++ [ ("up-" + cfg.nsname) ("br-" + cfg.nsname) ]);
        netif2ns = pkgs.writeScript "moveIfToNS-${cfg.nsname}" ''
          #! ${pkgs.stdenv.shell} -e
          set -x

          WHITELIST="${toString cfg.whitelist}"
          BLACKLIST="${toString blacklistedInterfaces}"
          NS="${cfg.nsname}"

          info() { ${config.systemd.package}/bin/systemd-cat -p info -t "udev-if2ns-$NS" <<< "$@"; }
          error() { ${config.systemd.package}/bin/systemd-cat -p err -t "udev-if2ns-$NS" <<< "$@"; }

          if ! ${pkgs.iproute}/bin/ip netns list | grep "$NS"; then
            error "Requested interface isolation but namespace $NS does not exist."
            exit 2
          fi

          if [ -z "$INTERFACE" ]; then error "Requested interface isolation for null interface!"; exit 1; fi

          if ! ${pkgs.iproute}/bin/ip l show $INTERFACE &>/dev/null; then
            info "Triggered interface not available, probably leaving..."
            exit 0
          fi

          move() {
            ADDRS="$(${pkgs.iproute}/bin/ip l show $INTERFACE | tail -n 1 | ${pkgs.busybox}/bin/awk '{print $2"/"$4}')"
            STATE="$(${pkgs.iproute}/bin/ip l show $INTERFACE | head -n 1 | ${pkgs.busybox}/bin/awk '{print $3}')"
            info "Moving $INTERFACE($ADDRS) into $NS -- $STATE"

            # FIXME: This does not detect wext interfaces, seems that the only way to do so is via ioctl...
            if [ -d /sys/class/net/$INTERFACE/phy80211 ]; then
                # Interface is wifi (as of NetworkManager)
                PHY_IDX="$(${pkgs.iw}/bin/iw dev $INTERFACE info | grep wiphy | ${pkgs.busybox}/bin/awk '{print $2}')"
                if [ -z "$PHY_IDX" ]; then
                    error "Could not determine wiphy index for interface $INTERFACE"
                    exit 1
                fi

                info "$INTERFACE is holding phy#$PHY_IDX, moving phy into $NS"

                ${pkgs.iw}/bin/iw phy#$PHY_IDX set netns name $NS
            else
                # Set the interface netns via RTNETLINK
                ${pkgs.iproute}/bin/ip link set $INTERFACE netns $NS
            fi

            exit 0
          }

          # Interface is whitelisted
          if [ -n "$(echo $WHITELIST | grep $INTERFACE)" ]; then
            info "Exporting whitelisted interface $INTERFACE"
            move
          fi

          # Interface is blacklisted
          if [ -n "$(echo $BLACKLIST | grep $INTERFACE)" ]; then
            info "Not exporting interface $INTERFACE (interface blacklisted)."
            exit 0
          fi

          ${if !cfg.dynamic then ''
            info "Not exporting interface $INTERFACE (dynamic displacement disabled)."
            exit 0
          '' else ''
            if ! [ "$ACTION" = "ADD" ]; then
                # Don't dynamically export already-bound interfaces...
                info "Not dynamically exporting configured interface $INTERFACE"
                exit 0
            fi
          ''}

          move
        '';
      in ''
        SUBSYSTEM=="net", ACTION=="*", KERNEL=="*", RUN+="${netif2ns}"
     '';
  };
}
