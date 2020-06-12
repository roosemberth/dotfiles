{ config, lib, pkgs, secrets, ... }:

let
  hostname = config.networking.hostName;
  uuids = {
    bootPart = "1f9a0153-ea97-49bc-a2a7-b679e46679ae";
    systemDevice = "2452fc3b-7c05-4024-9d08-3be509a645cd";
  };
in
{
  boot = {
    cleanTmpDir = true;
    initrd = {
      availableKernelModules = [ "xhci_pci" "nvme" "sd_mod" ];
      kernelModules = ["dm_crypt" "cbc" "kvm-intel" "e1000e"];
      luks.devices."${hostname}".device = "/dev/disk/by-uuid/${uuids.systemDevice}";
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

  hardware.enableRedistributableFirmware = true;

  swapDevices = [
    { device = "/mnt/root-btrfs/subvolumes/swap/swapfile1"; }
  ];

  fileSystems = {
    "/" = {
      fsType = "btrfs";
      mountPoint = "/";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/rootfs" "compress=zlib" "user_subvol_rm_allowed"];
    };
    "/boot" = {
      fsType = "vfat";
      mountPoint = "/boot";
      device = "/dev/disk/by-partuuid/${uuids.bootPart}";
    };
    "/var" = {
      fsType = "btrfs";
      mountPoint = "/var";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/var" "compress=zlib" "user_subvol_rm_allowed"];
    };
    "/nix" = {
      fsType = "btrfs";
      mountPoint = "/nix";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/nix" "compress=zlib" "defaults" "noatime" "autodefrag" "nodatacow"];
    };
    "/home" = {
      fsType = "btrfs";
      mountPoint = "/home";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/active/home" "compress=zlib" "autodefrag" "user_subvol_rm_allowed"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/rootfs" "defaults" "user_subvol_rm_allowed"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      mountPoint = "/home/.snapshots";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=/subvolumes/snapshots/home" "defaults" "user_subvol_rm_allowed"];
    };
    "/mnt/root-btrfs" = {
      fsType = "btrfs";
      mountPoint = "/mnt/root-btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["nodatacow" "noatime" "noexec" "user_subvol_rm_allowed"];
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  services.snapper.configs = let
    extraConfig = ''
      TIMELINE_CREATE="yes"
      TIMELINE_CLEANUP="yes"
      EMPTY_PRE_POST_CLEANUP="yes"
      SYNC_ACL="yes"
    '';

    mkCfg = path: {
      subvolume = path;
      inherit extraConfig;
    };

    userCfg = user: path: {
      subvolume = path;
      extraConfig = extraConfig + ''
        ALLOW_USERS="${user}"
      '';
    };
  in {
    "home" = mkCfg "/home";
    "roos-var" = userCfg "roosemberth" "/home/roosemberth/.local/var";
    "roos-ws" = userCfg "roosemberth" "/home/roosemberth/ws";
    "roos-ws-platforms" = userCfg "roosemberth" "/home/roosemberth/ws/2-Platforms";
  };
}
