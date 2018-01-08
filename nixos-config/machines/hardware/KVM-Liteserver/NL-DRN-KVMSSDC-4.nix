{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  boot = {
    loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/sda";
      timeout = 1;
      splashImage = null;
    };

    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "sd_mod" "sr_mod" ];

      network = {
        enable = true;
        ssh.enable = true;
        ssh.authorizedKeys = [ "${builtins.readFile /etc/nixos/roos_rsa.pub}" ];
	ssh.hostRSAKey = "/etc/nixos/dropbear_rsa"; # generate with # dropbearkey -t rsa  -f /etc/nixos/dropbear_rsa
      };

      luks.devices."Heimdaalr".device = "/dev/disk/by-uuid/73a68e6f-eba9-4398-bcfc-bce06ee2efbc";
      supportedFilesystems = [ "btrfs" "ext4" ];
    };
  };

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

  swapDevices = [
    { device = "/dev/sda2";
      randomEncryption = { enable = true; cipher = "serpent-xts"; };
    # randomEncryption = true;
    }
  ];

  nix.maxJobs = lib.mkDefault 1;
}
