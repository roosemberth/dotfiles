{ config, lib, pkgs, ... }:

{
  imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 8;
  powerManagement = {
    cpuFreqGovernor = "powersave";
    resumeCommands =
    ''
      ${config.systemd.package}/bin/systemctl restart bluetooth.service
    '';
    powerDownCommands =
    ''
      ${config.systemd.package}/bin/systemctl stop bluetooth.service
    '';
  };

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
   #  systemd-boot.enable = true;
      grub = {
        enable = true;
        version = 2;
        efiSupport = true;
        device = "nodev";
        gfxmodeEfi = "1280x1024x32,1024x768x32,auto";
      };
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      kernelModules = ["dm_crypt" "cbc" "aes_x86_64"];
      luks = {
        devices = [
          { name = "Lenstra";
            device = "/dev/disk/by-uuid/031796d1-9617-402e-a106-7c5a622ebdd0";
          } {
            name = "Triglav";
            device = "/dev/disk/by-uuid/cd56ef5b-74bd-426e-96de-c1ccd2b0de72";
          }
        ];
      };
    };
  };

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/Lenstra";
      options = ["subvol=/var/machines/Vesna/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/Lenstra";
      options = ["subvol=/var/machines/Vesna/subvolumes/snapshots/rootfs" "defaults" "noatime"];
    };
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/sda1";
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/Lenstra";
      options = ["subvol=/var/machines/Vesna/subvolumes/.__active__/var" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
  # "/home" = {
  #   fsType = "btrfs";
  #   mountPoint = "/home";
  #   device = "/dev/mapper/Lenstra";
  #   options = ["subvol=/var/machines/Vesna/subvolumes/.__active__/homes" "defaults" "noatime" "compress=zlib" "autodefrag"];
  # };
  # "/Storage" = {
  #   fsType = "btrfs";
  #   mountPoint = "/Storage";
  #   device = "/dev/mapper/Lenstra";
  #   options = ["subvol=/var/machines/Vesna/subvolumes/.__active__/Storage" "defaults" "noatime" "compress=zlib" "autodefrag"];
  # };
  # "/home/.snapshots" = {
  #   fsType = "btrfs";
  #   mountPoint = "/home/.snapshots";
  #   device = "/dev/mapper/Lenstra";
  #   options = ["subvol=/var/machines/Vesna/subvolumes/snapshots/homes" "defaults" "noatime"];
  # };
  # "/Storage/.snapshots" = {
  #   fsType = "btrfs";
  #   mountPoint = "/Storage/.snapshots";
  #   device = "/dev/mapper/Lenstra";
  #   options = ["subvol=/var/machines/Vesna/subvolumes/snapshots/Storage" "defaults" "noatime"];
  # };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/.__active__/homes" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/Storage" = {
      fsType = "btrfs";
      mountPoint = "/Storage";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/.__active__/Storage" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/Storage/DevelHub" = {
      fsType = "btrfs";
      mountPoint = "/Storage/DevelHub";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/.__active__/DevelHub" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/home/.snapshots";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/snapshots/homes" "defaults" "noatime"];
    };
    "/Storage/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/Storage/.snapshots";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/snapshots/Storage" "defaults" "noatime"];
    };
    "/Storage/DevelHub/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/Storage/DevelHub/.snapshots";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/snapshots/DevelHub" "defaults" "noatime"];
    };
    "/mnt/root-btrfs-Lenstra" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs-Lenstra";
      device = "/dev/mapper/Lenstra";
      options = ["nodatacow" "noatime" "noexec"];
    };
    "/mnt/root-btrfs-Triglav" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs-Triglav";
      device = "/dev/mapper/Triglav";
      options = ["nodatacow" "noatime" "noexec"];
    };
  };
}
