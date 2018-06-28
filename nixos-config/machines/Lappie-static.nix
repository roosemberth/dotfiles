{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  partuuid = {
    efi = "39066bf7-3e27-4f66-9a7b-342d2f1a4927";
    swap = "a75a2251-d065-4340-b939-4cef7dcdc1b4";
    system = "ffce823b-1376-411f-844c-3336b3b59890";
  };
  secrets = import ../secrets.nix { inherit lib; };
in
{
  boot = {
    cleanTmpDir = true;
    kernelPackages = pkgs.linuxPackages_hardened;
    kernelParams = [ "ip=10.42.13.21::10.42.13.1:255.255.255.0:lappie.intranet.orbstheorem.ch:eth0" ];
    initrd = {
      kernelModules = ["dm_crypt" "cbc" "aes_x86_64" "iwlwifi" "r8169"];
      luks.devices."${hostname}".device = "/dev/disk/by-partuuid/${partuuid.system}";
      network = {
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
      };
      timeout = 1;
    };
  };

  swapDevices = [ { device = "/dev/disk/by-partuuid/${partuuid.swap}"; randomEncryption = true; } ];

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/nix" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/.__active__/nix" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/var" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/.__active__/var" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/boot" = {
      fsType = "vfat";
      device = "/dev/disk/by-partuuid/${partuuid.efi}";
    };
    "/home" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/.__active__/homes" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/Storage" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/.__active__/Storage" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/snapshots/homes" "defaults" "noatime"];
    };
    "/Storage/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/var/machines/${hostname}/subvolumes/snapshots/Storage" "defaults" "noatime"];
    };
    "/mnt/root-btrfs-${hostname}" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["nodatacow" "noatime" "noexec"];
    };
  };

  powerManagement.cpuFreqGovernor = "performance";
}
