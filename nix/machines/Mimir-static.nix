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

  roos.layout-trees = {
    enable = true;
    mounts."/home/roosemberth" = {
      layout_tree = "/mnt/root-btrfs/subvolumes/per-dataset/@roosemberth";
      tree_prefix = "/mnt/root-btrfs";
      device_path = "/dev/mapper/" + hostname;
      extra_opts = [ "user_subvol_rm_allowed" "compress=zlib" "relatime" ];
    };
    mounts."/" = {
      layout_tree = "/mnt/root-btrfs/subvolumes/per-dataset/@mimir-local";
      tree_prefix = "/mnt/root-btrfs";
      device_path = "/dev/mapper/" + hostname;
      extra_opts = [ "compress=zstd" "relatime" ];
    };
  };

  environment.etc."machine-id".source = "/var/lib/secrets/machine-id";
  environment.etc."wireplumber/main.lua.d/70-rename-dac.lua".text = ''
    -- Most applications show the description: Set it to a reasonable value...
    rule = {
      matches = {{
        { "alsa.long_card_name", "=", "LENOVO-20QESA0V00-ThinkPadX1Carbon7th" },
        { "device.profile.description", "=", "Speaker + Headphones" },
      }},
      apply_properties = {
        ["node.description"] = "Laptop Speaker/Headphones",
        ["node.nick"] = "Laptop Speaker/Headphones",
      },
    }
    table.insert(alsa_monitor.rules, rule)
  '';

  systemd.services.fix-generated-mounts-permissions = {
    description = "Fix directory permissions of the @roosemberth dataset"
      + " mounts created by the layout-trees generator.";
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

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  security.tpm2.enable = true;
  services.btrfs.autoScrub.enable = true;
  services.fwupd.enable = true;

  sops.secrets."ssh-client/backups-key" = {};
}
