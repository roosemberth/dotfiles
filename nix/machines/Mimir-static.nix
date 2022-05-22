{ config, lib, pkgs, secrets, ... }:

let
  hostname = config.networking.hostName;
  uuids = {
    bootPart = "e9f1777b-c68f-4b5d-bcf0-db9e0d8b1199";
    systemDevice = "8e4808d8-0b50-4f98-b796-9c09d9d39a94";
  };
in
{
  boot = {
    cleanTmpDir = true;
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "sd_mod" ];
      kernelModules = ["dm_crypt" "cbc" "kvm-intel" "e1000e"];
      luks.devices."${hostname}" = {
        device = "/dev/disk/by-partuuid/${uuids.systemDevice}";
        postOpenCommands = ''
          mkdir "/tmp-${hostname}-root"
          mount -t btrfs "/dev/mapper/${hostname}" "/tmp-${hostname}-root"
          cd "/tmp-${hostname}-root/subvolumes/ephemeral"

          EPH_VERSION="$(date -u +%y%m%dZ%H%M)"
          mkdir -p "$EPH_VERSION"
          for v in $(ls -v1 templates); do  # Generate ephemeral volumes
            btrfs subvolume snapshot "templates/$v" "$EPH_VERSION/$v"
          done
          rm active
          ln -sf "$EPH_VERSION" active

          for v in $(ls -v1 | grep -v templates); do
            if ! date -d "$v" &> /dev/null; then
              echo -n "WARNING: Could not determine whether to clean up " >&2
              echo "ephemeral version $v" >&2
              continue
            fi
            if [ $(date -d "$v" +%s) -lt $(date 'now - 7 days' +%s) ]; then
              echo "Deleting old ephemeral system version $v"
              for sv in $(ls -v1 "$v"); do
                btrfs subvolume delete "$v/$sv"
              done
              rm -fr "$v"
            fi
          done

          cd
          umount "/tmp-${hostname}-root"
        '';
      };
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
    kernelModules = ["acpi_call"];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call v4l2loopback ];
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
        gfxmodeEfi = "1280x1024x32,1024x768x32,auto";
      };
    };
  };

  hardware.enableRedistributableFirmware = true;

  swapDevices = [
    { device = "/mnt/root-btrfs/subvolumes/swap/swapfile1"; }
  ];

  fileSystems = {
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/disk/by-partuuid/${uuids.bootPart}";
    };
    "/nix" = {
      fsType = "btrfs";
      mountPoint = "/nix";
      device = "/dev/mapper/" + hostname;
      options = [
        "compress=zlib"
        "defaults"
        "noatime"
        "nodatacow"
        "subvol=/subvolumes/persisted/@nix"
      ];
    };
    "/mnt/root-btrfs" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["nodatacow" "noatime" "noexec" "user_subvol_rm_allowed"];
      neededForBoot = true; # Generated user mount units require to know the layout.
    };

    # Ephemeral volumes
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/ephemeral/active/rootfs" "compress=zlib"];
    };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/" + hostname;
      options = [
        "subvol=/subvolumes/ephemeral/active/home"
        "compress=zlib"
        "user_subvol_rm_allowed"
      ];
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/ephemeral/active/var" "compress=zlib"];
    };
  };

  roos.user-mounts-generator = {
    enable = true;
    mounts."/home/roosemberth" = {
      layout_tree = "/mnt/root-btrfs/subvolumes/per-dataset/@roosemberth";
      tree_prefix = "/mnt/root-btrfs";
      device_path = "/dev/mapper/" + hostname;
      extra_opts = [ "user_subvol_rm_allowed" "compress=zlib" "relatime" ];
    };
  };

  systemd.services.fix-generated-mounts-permissions = {
    description = "Fix directory permissions of directories created for"
      + " mount points of units created by user-mounts-generator.";
    path = with pkgs; [ gawk util-linux  ];
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.ExecStart = builtins.toString
      (pkgs.writeShellScript "fix-user-mount-point-perms" (''
      while read mnt; do
        while echo $mnt | grep -q "^/home/roosemberth"; do
          echo "Setting owner of $mnt to user roosemberth"
          chown roosemberth:users "$mnt"
          mnt="'' + "\${mnt%/*}" + ''"
        done
      done <<< $(mount | grep /subvolumes/per-dataset/@roosemberth | awk '{print $3}')
    ''));
  };

  # TODO: Migrate to wireplumber
  services.pipewire.wireplumber.enable = false;
  services.pipewire.media-session.enable = true;
  services.pipewire.media-session.config.bluez-monitor.rules = [{
    # Matches all bluetooth cards
    matches = [ { "device.name" = "~bluez_card.*"; } ];
    actions."update-props" = {
      "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
      # mSBC is not expected to work on all headset + adapter combinations.
      "bluez5.msbc-support" = true;
    };
  } {
    matches = [
      { "node.name" = "~bluez_input.*"; }
      { "node.name" = "~bluez_output.*"; }
    ];
    actions."node.pause-on-idle" = false;
  }];

  services.pipewire.media-session.config.alsa-monitor.rules = [{
    matches = [{
      "node.description" =
        "Cannon Point-LP High Definition Audio Controller Speaker + Headphones";
    }];
    actions."update-props"."node.description" = "Laptop DSP";
    actions."update-props"."node.nick" = "Laptop audio";
    # Workaround odd bug on the session-manager where output will start in bad state.
    actions."update-props"."api.acp.autoport" = true;
  } {
    matches = [{
      "node.description" =
        "Cannon Point-LP High Definition Audio Controller Digital Microphone";
    }];
    actions."update-props"."node.description" = "Laptop Mic";
    actions."update-props"."node.nick" = "Laptop mic";
  } {
    matches = [{
      "node.description" = "~Cannon Point-LP High Definition Audio.*";
    }];
    actions."update-props"."node.pause-on-idle" = true;
  }];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  security.tpm2.enable = true;
  services.btrfs.autoScrub.enable = true;
  services.fwupd.enable = true;

  sops.secrets."ssh-client/backups-key" = {};
}
