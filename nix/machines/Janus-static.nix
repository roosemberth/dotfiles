{ config, lib, pkgs, ... }: let
  hostname = config.networking.hostName;
  originalConfig = config; # Used in vmVariant.
  systemDevice = "/dev/mapper/${hostname}-system";
  systemLuksDevice = "/dev/disk/by-partlabel/${hostname}-system-luks";
in {
  boot = {
    initrd.luks.devices."${hostname}-system" = {
      device = systemLuksDevice;
      postOpenCommands = ''
        ${pkgs.substituteAll {
          src = ./rotate-active-submodule-versions.sh;
          isExecutable = true;
          rootfsDevice = systemDevice;
        }}
      '';
    };
    loader.efi.efiSysMountPoint = "/boot";
    loader.grub = {
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
      gfxmodeEfi = "1280x1024x32,1024x768x32,auto";
    };
  };

  environment.etc."machine-id".source = "/var/lib/secrets/machine-id";

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      device = systemDevice;
      options = [
        "compress=zstd"
        "subvol=/subvolumes/versioned/active/rootfs"
      ];
    };
    "/boot" = {
      fsType = "vfat";
      device = "/dev/disk/by-partlabel/${hostname}-efi";
    };
    "/mnt/system-btrfs-default-volume" = {
      fsType = "btrfs";
      device = systemDevice;
      options = [
        "noatime"
        "nodatacow"
        "noexec"
      ];
      neededForBoot = true; # Generated user mount units require to know the layout.
    };
    "/nix" = {
      fsType = "btrfs";
      device = systemDevice;
      options = [
        "compress=zstd:15"
        "noatime"
        "nodatacow"
        "subvol=/subvolumes/@nix-store"
      ];
    };
    "/var" = {
      fsType = "btrfs";
      device = systemDevice;
      options = [
        "compress=zstd"
        "subvol=/subvolumes/versioned/active/var"
      ];
    };
  };

  roos.layout-trees = {
    enable = true;
    mounts."/var/home/roosemberth" = {
      layout_tree = "/mnt/system-btrfs-default-volume/subvolumes/datasets/@roosemberth";
      tree_prefix = "/mnt/system-btrfs-default-volume";
      device_path = systemDevice;
      extra_opts = [ "compress=zstd" "relatime" "user_subvol_rm_allowed" ];
    };
    mounts."/" = {
      layout_tree = "/mnt/system-btrfs-default-volume/subvolumes/datasets/@${hostname}";
      tree_prefix = "/mnt/system-btrfs-default-volume";
      device_path = systemDevice;
      extra_opts = [ "compress=zstd" "relatime" ];
    };
  };

  systemd.services.fix-generated-mounts-permissions = {
    description = "Fix directory permissions of the @roosemberth dataset"
      + " mounts created by the layout-trees generator.";
    path = with pkgs; [ gawk util-linux  ];
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig.ExecStart = builtins.toString
      (pkgs.writeShellScript "fix-user-mount-point-perms" (''
      while read mnt; do
        while echo $mnt | grep -q "^/var/home/roosemberth"; do
          echo "Setting owner of $mnt to user roosemberth"
          chown roosemberth:users "$mnt"
          mnt="'' + "\${mnt%/*}" + ''"
        done
      done <<< $(mount | grep /subvolumes/datasets/@roosemberth | awk '{print $3}')
    ''));
  };

  virtualisation.vmVariant = {
    imports = [
      ({config, ...}: { # Prepare disk image.
        boot.initrd.extraUtilsCommands = ''
          # mkfs.btrfs is necessary in the initrd to create a btrfs filesystem.
          copy_bin_and_libs ${pkgs.btrfs-progs}/bin/mkfs.btrfs
        '';

        # This is better suited at the beginning of postDeviceCommands, but we
        # have no way of reliably inserting it before other code.
        boot.initrd.preLVMCommands = ''
          ${
            if config.virtualisation.useBootLoader
            then ""
            else ''
              # "Fake" the partition which would be discovered if the disk image
              # had partitions.
              mkdir -p "/dev/disk/by-partlabel"
              ln -s "${config.virtualisation.rootDevice}" "${systemLuksDevice}"
            ''
          }
          # If the disk image appears to be empty, initialize it.
          FSTYPE="$(blkid -o value -s TYPE "${systemLuksDevice}" || true)"
          PARTTYPE="$(blkid -o value -s PTTYPE "${systemLuksDevice}" || true)"
          if test -z "$FSTYPE" -a -z "$PARTTYPE"; then
              echo "Drive seems to be empty, initializing (may take a minute)..."
              echo -n 1234 | cryptsetup luksFormat --key-file - "${systemLuksDevice}"
              echo -n 1234 | cryptsetup open "${systemLuksDevice}" \
                "$(basename "${systemDevice}")"
              mkfs.btrfs "${systemDevice}"
              TMPDIR="$(mktemp -dt rootfs.XXXXXX)"
              mount "${systemDevice}" "$TMPDIR"
              # Prepare subvolume templates for rotating versions.
              echo "Preparing filesystem."
              mkdir -p "$TMPDIR/subvolumes/versioned/templates"
              cd "$TMPDIR/subvolumes/versioned/templates"
              btrfs subvolume create rootfs
              btrfs subvolume create var
              cd -
              # Tidy-up
              umount "$TMPDIR"
              rmdir "$TMPDIR"
              cryptsetup luksClose "$(basename "${systemDevice}")"
          fi
        '';
      })
      ({config, ...}: let # Configure filesystms in VM
        fsToExclude =
          [
            "/nix" # Provided by nixos/modules/virtualisation/qemu-vm.nix
          ] ++ lib.optionals (!config.virtualisation.useBootLoader) [
            "/boot" # Not available without a bootloader.
          ];
      in {
        virtualisation = {
          # nixos/modules/virtualisation/qemu-vm.nix overrides the filesystems
          # defined in config.fileSystems.
          fileSystems =
            lib.filterAttrs
              (name: _: !lib.elem name fsToExclude)
              originalConfig.fileSystems;
          rootDevice = lib.mkIf (!config.virtualisation.useBootLoader) "/dev/vda";
          # The default filesystems provided by the virtualisation module are
          # very simple and would prevent testing some behaviour.
          useDefaultFilesystems = false;
          useEFIBoot = true;
          qemu.options = [
            "-chardev stdio,mux=on,id=char0,signal=off"
            "-device virtio-balloon-pci,id=balloon0,bus=pci.0"
            "-mon chardev=char0,mode=readline"
            "-serial chardev:char0"
            "-vga cirrus"
          ];
        };
      })
    ];
  };
}
