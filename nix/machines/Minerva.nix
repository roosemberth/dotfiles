{ config, pkgs, lib, ... }:
let
  networkConfig = { secrets, ... }: let
    hostBridgeV4Addrs = [{ address = "10.231.136.1"; prefixLength = 24; }];
  in {
    # Disable autoconf of the physical adapter. See bellow.
    boot.kernel.sysctl."net.ipv6.conf.enp0s31f6.disable_ipv6" = 1;
    networking = {
      hostName = "Minerva";
      useNetworkd = true;
      useDHCP = false;

      # Make a bridge and join the physical adapter to share the network segment.
      bridges.orion.interfaces = [ "enp0s31f6" ];
      interfaces.orion.useDHCP = true;
      interfaces.orion.tempAddress = "disabled";

      nat.enable = true;
      nat.externalInterface = "orion";  # Use the bridge to access the world.

      # Ask the named container to resolve DNS for us.
      nameservers = with secrets.network.zksDNS; v6 ++ v4;
      search = with secrets.network.zksDNS; [ search ];
    };

    services.resolved = {
      dnssec = "false";  # The named container is not configured to do DNSSEC.
      llmnr = "true";  # orion is a trusted network.
      extraConfig = ''
        # Allow queries from containers.
        ${lib.concatMapStringsSep "\n"
            (v: "DNSStubListenerExtra=${v.address}") hostBridgeV4Addrs}
      '';
    };

    roos.container-host = {
      enable = true;
      # Have the containers join the network segment of the physical adapter.
      # This allows them to have IPv6 for free.
      iface.name = "orion";
      iface.ipv4.addresses = hostBridgeV4Addrs;
      # Cache DNS for containers.
      # This implies containers can resolve protected networks.
      nameservers = map (v: v.address) hostBridgeV4Addrs;
    };

    networking.firewall.extraCommands = ''
      iptables -w -t nat -D POSTROUTING -j minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -F minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -X minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -N minerva-nat-post
      # Assent connections from the monitoring into Yggdrasil.
      iptables -w -t nat -I minerva-nat-post \
        -s 10.231.136.6 -d 10.13.0.0/16 -j MASQUERADE
      # Hairpin so inter-container responses match expected source address.
      iptables -w -t nat -I minerva-nat-post \
        -s 10.231.136.0/24 -d 10.231.136.0/24 -j MASQUERADE
      iptables -w -t nat -I POSTROUTING -j minerva-nat-post
    '';
  };
  nasConfig = let
    probe-nas-disk = pkgs.writeShellScript "probe-nas-disk" ''
      N_BAY="$1"

      if [ -z "$N_BAY" ]; then
        echo "Missing required argument: Number of the NAS bay to probe."
        exit
      fi

      TARGET_UNLOCKED_DEVICE="/dev/mapper/nas-$N_BAY"
      DEVICE_PATH="/dev/qnap-bay$N_BAY"

      if [ -e "$TARGET_UNLOCKED_DEVICE" ]; then
        exit; # The drive corresponding to this bay is already unlocked.
      fi

      if [ ! -e "$DEVICE_PATH" ]; then
        exit; # The drive we are being notified for is not there.
      fi

      echo "I received notice that NAS drive in $N_BAY is available."

      LOCKED_VOLUMES="$(${pkgs.util-linux}/bin/lsblk -fJp "$DEVICE_PATH" \
        | ${pkgs.jq}/bin/jq -r '
            .blockdevices[]
          | .children[]
          | select(.fstype=="crypto_LUKS" and .children==null)
          | .name
        ')"

      if [ -z "$LOCKED_VOLUMES" ]; then
        echo "The disk in bay $N_BAY doesn't seem to contain any encrypted volumes."
        exit
      fi

      echo "I found the following encrypted volumes in disk in bay $N_BAY:" \
           "$(echo "$LOCKED_VOLUMES" | ${pkgs.coreutils}/bin/tr -d '\n')." \
           "I will try them until succesfully unlocking one."

      for device in $LOCKED_VOLUMES; do
        ${pkgs.cryptsetup}/bin/cryptsetup -q \
          luksOpen "$device" "$(basename "$TARGET_UNLOCKED_DEVICE")" \
          --key-file /root/cabinet-keyfile || continue
        # Decription suceeded
        echo "I successfully unlocked $device as $TARGET_UNLOCKED_DEVICE."

        echo "Checking whether we can mount $TARGET_UNLOCKED_DEVICE already."
        if ${pkgs.btrfs-progs}/bin/btrfs \
              filesystem show "$TARGET_UNLOCKED_DEVICE" 2>&1 \
            | grep -q 'Some devices missing'; then
          echo "$TARGET_UNLOCKED_DEVICE cannot be mounted: Some devices missing."
        else
          if ${pkgs.util-linux}/bin/findmnt /mnt/cabinet >/dev/null; then
            echo "$TARGET_UNLOCKED_DEVICE already mounted. Race condition?"
            exit
          fi
          echo "Attempting to mount $TARGET_UNLOCKED_DEVICE."
          if ${pkgs.util-linux}/bin/mount \
            "$TARGET_UNLOCKED_DEVICE" -t btrfs /mnt/cabinet; then
            echo "Succesfully mounted $TARGET_UNLOCKED_DEVICE."
          fi
        fi
        exit
      done

      echo "I could not unlock any of the encrypted volumes of disk in bay $N_BAY."
      exit
    '';
  in {
    services.udev.packages = lib.toList (pkgs.writeTextFile {
      name = "nas-udev-rules";
      destination = "/etc/udev/rules.d/150-probe-nas-disks.rules";
      text = let
        unitName = "probe-disk-on-nas-bay@%E{NAS_DISK_IDX}";
        cmd = "${pkgs.systemd}/bin/systemctl --no-block start ${unitName}";
      in ''
        ENV{NAS_DISK_IDX}=="[1-9]" RUN+="${cmd}"
      '';
    });

    systemd.services."probe-disk-on-nas-bay@" = {
      description = "Reacts to state changes of a disk in the given NAS bay.";
      serviceConfig.ExecStartPre = "${pkgs.systemd}/bin/udevadm settle";
      serviceConfig.ExecStart = "${probe-nas-disk} %i";
    };
  };
  containerHostConfig = {
    roos.container-host.hostDataDir = "/mnt/cabinet/minerva-data";

    systemd.services."container-host-volumes" = {
      requires = [ "mnt-cabinet.mount" ];
      after = [ "mnt-cabinet.mount" ];
    };
  };
in {
  imports = [
    ../modules
    ./Minerva-static.nix
    ./containers/databases.nix
    ./containers/home-automation.nix
    ./containers/named.nix
    ./containers/nextcloud.nix
    ./containers/matrix.nix
    ./containers/monitoring.nix
    ./containers/powerflow.nix
    ./containers/collabora.nix
    networkConfig
    nasConfig
    containerHostConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernelModules = [ "kvm-intel" ];

  environment.systemPackages = with pkgs; [
    gitAndTools.git-annex
    nvim-roos-essential
  ];

  hardware.cpu.intel.updateMicrocode = true;

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.package = pkgs.nixUnstable;
  nix.settings.trusted-users = [ "roosemberth" ];

  roos.dotfilesPath = ../..;
  roos.nginx-fileshare.enable = true;
  roos.nginx-fileshare.directory = "/srv/shared";
  roos.user-profiles.reduced = ["roosemberth"];
  roos.wireguard.enable = true;
  roos.wireguard.network = "bifrost-via-heimdaalr";

  programs.mosh.enable = true;
  security.pam.enableSSHAgentAuth = true;
  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''HandlePowerKey="ignore"'';
    netdata.enable = true;
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    prometheus.exporters.node.enable = true;
    prometheus.exporters.node.enabledCollectors = [ "systemd" ];
    tlp.enable = true;
    tlp.settings.CPU_SCALING_GOVERNOR_ON_AC = "performance";
    upower.enable = true;
  };

  # Imperative NixOS containers are affected by this.
  systemd.services."container@".serviceConfig.TimeoutStartSec =
    lib.mkForce "20min";
  # wait-online is very annoying and in most cases useless with my config.
  systemd.network.wait-online.anyInterface = true;

  system.stateVersion = "22.05";
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  time.timeZone = "Europe/Zurich";

  users = {
    mutableUsers = false;
    motd = with config; ''
      Welcome to ${networking.hostName}

      - This machine is managed by NixOS
      - All changes are futile

      OS:      NixOS ${system.nixos.release} (${system.nixos.codeName})
      Version: ${system.nixos.version}
      Kernel:  ${boot.kernelPackages.kernel.version}
    '';
  };
}
