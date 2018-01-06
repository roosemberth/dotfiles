{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
  ];

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 8;

  boot = {
    loader.grub.enable = true;
  # loader = {
  #   systemd-boot.enable = true;
  #   grub = {
  #     enable = true;
  #     version = 2;
  #     efiSupport = false;
  #   };
  # };
    initrd = {
      network = {
        enable = true;
        ssh.enable = true;
        ssh.shell = "${pkgs.bash}/bin/bash";
        ssh.authorizedKeys = [ "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD7lvqvX2oolM2JFRjkC41etZ7GPUWsMxxkINwXPgtXLeqyArb/rwnRR46tzJhwwvl6o4ZOEPs4clrbwKS6iI1UoSP8VZKCtNUrIxSxoBV/oVgurl5QY1qTfNtJeMqcHjwNxVcc6kJE0a7aI1TnfKUaN+kalwX68/bEyOxq7JeAou+rbfSKPCCP/TkQNZmwH6kbDe59O1/Ye9esB2Ri15U6POVTSt/FdvVpcVFa4YuuU2/EqQSAGtIX48FusAPUyNnsEyxH/bd3JiuxpNHJDSLIeLka1ePNpZ6Iql/mF4v+Rc8X1zDTltRk9eU67fYndPplzSWBB+ORcaoVIhtltSeN roosemberth@Azulejo-Main-Engine" ];
      };
      luks = {
        cryptoModules = [ "dm_crypt" "cbc" "aes_x86_64" ];
        devices = [
          { name = "Heimdaalr";
            device = "/dev/disk/by-uuid/FC04005E-B90C-41F3-95F8-EF73A7ABA827";
          }
        ];
      };
      supportedFilesystems = [ "btrfs" ];
    };
  };

  fileSystems = {
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/sda1";
    };
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/homes" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/.__active__/var" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/snapshots/rootfs" "defaults" "noatime"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/home/.snapshots";
      device = "/dev/mapper/Heimdaalr";
      options = ["subvol=/var/machines/Heimdaalr/subvolumes/snapshots/homes" "defaults" "noatime"];
    };
  };
}
