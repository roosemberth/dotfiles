{ config, lib, pkgs, ... }:

let
  hostname = "Heimdaalr";
  partuuid = {
    boot = "6283960e-0d80-4455-a72a-3318c34cd1fb";
    system = "73a68e6f-eba9-4398-bcfc-bce06ee2efbc";
  };
  secrets = import ../secrets.nix { inherit lib; };
in
{
  imports = [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix> ];

  boot = {
    loader.timeout = 1;
    loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/sda";
      splashImage = null;
    };

    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "sd_mod" "sr_mod" ];

      network = {
        enable = true;
        ssh.enable = true;
        ssh.authorizedKeys = secrets.adminPubKeys;
        ssh.hostRSAKey = secrets.machines."${hostname}".hostInitrdRSAKey; 
      };

      luks.devices."${hostname}".device = "/dev/disk/by-partuuid/${partuuid.system}";
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
  };

  swapDevices = [ { device = "/dev/sda2"; randomEncryption = { enable = true; cipher = "serpent-xts"; }; } ];

  fileSystems = {
    "/boot" = {
      fsType = "ext4";
      device = "/dev/sda1";
    };
    "/" = {
      fsType = "btrfs";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/home" = {
      fsType = "btrfs";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/homes" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/var" = {
      fsType = "btrfs";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/var" "defaults" "noatime" "nodatacow" "compress=zlib" "autodefrag"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/snapshots/rootfs" "defaults" "noatime"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/snapshots/homes" "defaults" "noatime"];
    };
  };
}
