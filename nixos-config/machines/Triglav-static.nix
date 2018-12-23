{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  uuid = {
    triglav = "cd56ef5b-74bd-426e-96de-c1ccd2b0de72";
  };
  partuuid = {
    boot = "6283960e-0d80-4455-a72a-3318c34cd1fb";
  };
  secrets = import ../secrets.nix { inherit lib; };
in
{
  imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

  boot = {
    cleanTmpDir = true;
    kernelPackages = pkgs.linuxPackages_latest;
    initrd = {
      kernelModules = ["dm_crypt" "cbc" "aes_x86_64" "kvm-intel" "e1000e"];
      luks = {
        devices = [
          {
            name = "Triglav";
            device = "/dev/disk/by-uuid/${uuid.triglav}";
          }
        ];
      };
      network = if !secrets.secretsAvailable then {} else {
        enable = true;
        ssh.enable = true;
        ssh.authorizedKeys = secrets.adminPubKeys;
        ssh.hostRSAKey = secrets.machines."${hostname}".hostInitrdRSAKey; 
      };
      preDeviceCommands = "ip a || true";
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
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

  swapDevices = [ ];

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/snapshots/rootfs" "defaults" "noatime"];
    };
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/disk/by-partuuid/${partuuid.boot}";
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/Triglav";
      options = ["subvol=/subvolumes/.__active__/var" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
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
    "/mnt/root-btrfs-Triglav" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs-Triglav";
      device = "/dev/mapper/Triglav";
      options = ["nodatacow" "noatime" "noexec"];
    };
  };

  powerManagement.cpuFreqGovernor = "powersave";
}
