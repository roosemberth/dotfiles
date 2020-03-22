{ config, lib, pkgs, ... }:

let
  hostname = config.networking.hostName;
  diskUuid = {
    bootPart = "133f07bf-0c20-2f43-a991-06bf80d12b24";
    systemDevice = "40142004-2d27-4d60-88c6-2338aba3e5b4";
  };
  secrets = import ../secrets.nix { inherit lib; };
  intranetName = "${lib.strings.toLower hostname}";
  mkBootIpCfg = ll: "${ll.ip}::${ll.gw}:${ll.mask}:${intranetName}:eth0";
  ipBootCfg = mkBootIpCfg secrets.network.localLinkNetworks."${hostname}";
in
{
  boot = {
    cleanTmpDir = true;
    kernelPackages = pkgs.linuxPackages_hardened;
    kernelParams = [ "ip=${ipBootCfg}" ];
    initrd = {
      kernelModules = ["dm_crypt" "cbc" "aes_x86_64" "e1000e"];
      luks.devices."${hostname}".device = "/dev/disk/by-uuid/${diskUuid.systemDevice}";
      network = {
        enable = true;
        ssh.enable = true;
        ssh.authorizedKeys = secrets.adminPubKeys;
        ssh.hostRSAKey = secrets.machines."${hostname}".hostInitrdRSAKey;
        postCommands = "ip a || true";
      };
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

  fileSystems = assert diskUuid.bootPart != null && diskUuid.bootPart != "" &&
                       diskUuid.systemDevice != null && diskUuid.systemDevice != "";
  {
    "/boot" = {
      fsType = "vfat";
      device = "/dev/disk/by-partuuid/${diskUuid.bootPart}";
    };
    "/nix" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/.__active__/nix" "defaults" "noatime" "compress=zlib" "autodefrag" "nodatacow"];
    };
    "/var" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/.__active__/var" "defaults" "compress=zlib" "autodefrag" "nodatacow"];
    };
    "/" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/.__active__/rootfs" "defaults" "noatime" "compress=zlib" "autodefrag"];
    };
    "/home" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/.__active__/homes" "defaults" "compress=zlib" "autodefrag"];
    };
    "/Storage" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/.__active__/Storage" "defaults" "compress=zlib" "autodefrag"];
    };
    "/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/snapshots/rootfs" "defaults" "noatime"];
    };
    "/home/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/snapshots/homes" "defaults" "noatime"];
    };
    "/Storage/.snapshots" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["subvol=/subvolumes/snapshots/Storage" "defaults" "noatime"];
    };
    "/mnt/root-btrfs-${hostname}" = {
      fsType = "btrfs";
      device = "/dev/mapper/${hostname}";
      options = ["nodatacow" "noatime" "noexec"];
    };
  };

  powerManagement.cpuFreqGovernor = "performance";

  services.snapper.configs = let
    extraConfig = ''
      ALLOW_GROUPS="wheel"
      TIMELINE_CREATE="yes"
      TIMELINE_CLEANUP="yes"
      EMPTY_PRE_POST_CLEANUP="yes"
    '';
  in {
    "home" = {
      subvolume = "/home";
      inherit extraConfig;
    };
    "Storage" = {
      subvolume = "/Storage";
      inherit extraConfig;
    };
  };
}
