{ config, lib, pkgs, secrets, ... }:
let
  hostname = config.networking.hostName;
  uuids = {
    bootPart = "141D-400F";
    systemDevice = "a7f508da-7f10-4972-b1c0-b22ba4ede8f2";
  };
in
{
  boot = {
    initrd = {
      availableKernelModules = [ "e1000e" ];
      luks.devices."${hostname}".device =
        "/dev/disk/by-uuid/${uuids.systemDevice}";

      network.enable = true;
      network.ssh.enable = true;
      network.ssh.authorizedKeys = secrets.adminPubKeys;
      network.ssh.hostECDSAKey =
        (secrets.forHost hostname).keys.ssh-initramfs.minerva-initramfs-ecdsa;
      # network.udhcpc.command = "udhcpc6";
      network.postCommands = ''
        ip a add 10.0.18.20/24 dev enp0s31f6 || true
        ip l set dev enp0s31f6 up || true
        ip a
      '';

      supportedFilesystems = [ "btrfs" "vfat" ];
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
      device = "/dev/disk/by-uuid/${uuids.bootPart}";
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
