{ config, lib, pkgs, secrets, ... }:
let
  hostname = config.networking.hostName;
  uuids = {
    bootPart = "5d3ba400-a82a-6045-92be-23d12cfa9790";
    systemDevice = "a7f508da-7f10-4972-b1c0-b22ba4ede8f2";
  };
in
{
  boot = {
    initrd = {
      luks.devices."${hostname}".device =
        "/dev/disk/by-uuid/${uuids.systemDevice}";
      supportedFilesystems = [ "btrfs" ];
    };
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      gfxmodeEfi = "1280x1024x32,1024x768x32,auto";
    };
  };

  hardware.enableRedistributableFirmware = true;
  swapDevices = [ ];

  fileSystems =
  let
    bindActiveSubvolume = extraOpts: subvolName:
      bindBtrfsSubvol
        (extraOpts ++ ["user_subvol_rm_allowed"])
        "/subvolumes/active/${subvolName}";
    bindSnapshotSubvolume = extraOpts: subvolName:
      bindBtrfsSubvol
        (extraOpts ++ ["autodefrag" "defaults"])
        "/subvolumes/snapshots/${subvolName}";
    bindBtrfsSubvol = extraOpts: subvolPath: {
      fsType = "btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=${subvolPath}" "compress=zstd"] ++ extraOpts;
    };
  in {
    "/boot" = {
      fsType = "vfat";
      device = "/dev/disk/by-partuuid/${uuids.bootPart}";
    };
    "/" = bindActiveSubvolume [] "rootfs";
    "/var" = bindActiveSubvolume ["autodefrag"] "var";
    "/var/.snapshots" = bindSnapshotSubvolume [] "var";
    "/nix" = bindActiveSubvolume ["autodefrag" "noatime" "nodatacow"] "nix";
    "/home" = bindActiveSubvolume ["autodefrag"] "home";
    "/home/.snapshots" = bindSnapshotSubvolume [] "home";
    "/mnt/root-btrfs" = bindBtrfsSubvol ["nodatacow" "noatime" "noexec"] "/";
  };

  services.btrfs.autoScrub.enable = true;
  services.fwupd.enable = true;
  services.snapper.configs =
  let
    extraConfig = ''
      ALLOW_GROUPS="wheel"
      EMPTY_PRE_POST_CLEANUP="yes"
      SYNC_ACL="yes"
      TIMELINE_CLEANUP="yes"
      TIMELINE_CREATE="yes"
    '';

    mkCfg = path: {
      inherit extraConfig;
      subvolume = path;
    };
  in {
    "home" = mkCfg "/home";
    "var" = mkCfg "/var";
  };
}
