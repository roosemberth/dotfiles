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
    blacklistedKernelModules = [ "iTCO_wdt" ];
    initrd = {
      availableKernelModules = [ "e1000e" ];
      luks.devices."${hostname}".device =
        "/dev/disk/by-uuid/${uuids.systemDevice}";

      network.enable = true;
      network.ssh.enable = true;
      network.ssh.authorizedKeys = secrets.adminPubKeys;
      network.ssh.hostKeys =
        map (n: "/etc/secrets/initrd/ssh_host_${n}") ["ed25519" "ecdsa"];
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
  # See https://github.com/NixOS/nixpkgs/pull/91744 to restore this to hostKeys.
  #environment.etc."secrets/initrd/ssh_host_ed25519".source =
  #  (secrets.forHost hostname).keys.ssh-initramfs.ed25519;
  #environment.etc."secrets/initrd/ssh_host_ecdsa".source =
  #  (secrets.forHost hostname).keys.ssh-initramfs.ecdsa;

  hardware.enableRedistributableFirmware = true;
  swapDevices = [ ];

  fileSystems =
  let
    mainSubvol = subvol: opts:
      fromSubvol
        "/subvolumes/active/${subvol}"
        (opts ++ ["user_subvol_rm_allowed"]);
    snapshotSubvol = subvol: opts:
      fromSubvol
        "/subvolumes/snapshots/${subvol}"
        (opts ++ ["autodefrag" "defaults"]);
    fromSubvol = subvol: opts: {
      fsType = "btrfs";
      device = "/dev/mapper/" + hostname;
      options = ["subvol=${subvol}" "compress=zstd"] ++ opts;
    };
  in {
    "/boot".device = "/dev/disk/by-uuid/${uuids.bootPart}";

    "/"                = mainSubvol "rootfs" [];
    "/var"             = mainSubvol "var"    ["autodefrag"];
    "/nix"             = mainSubvol "nix"    ["autodefrag" "noatime" "nodatacow"];
    "/home"            = mainSubvol "home"   ["autodefrag"];

    "/var/.snapshots"  = snapshotSubvol "var"  [];
    "/home/.snapshots" = snapshotSubvol "home" [];

    "/mnt/root-btrfs"  = fromSubvol "/" ["nodatacow" "noatime" "noexec"];
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
