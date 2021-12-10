{ config, lib, pkgs, modulesPath, secrets, ... }: let
  hostname = config.networking.hostName;
  hostSecrets = secrets.forHost hostname;
  uuids = {
    boot = "2e4511ee-18a2-45d6-b085-c60bd23d6f50";
    luks = "f847edc7-886d-46d5-9579-a8b7c81db556";
  };
in {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.initrd = {
    luks.devices."${hostname}".device = "/dev/disk/by-uuid/${uuids.luks}";
    network.enable = true;
    network.postCommands = ''
      ip a add 5.255.96.101/24 dev ens3
      ip l set dev ens3 up
      ip r add default via 5.255.96.1
    '';
    network.ssh = with secrets; {
      enable = true;
      port = 22;
      authorizedKeys = secrets.adminPubKeys;
      hostKeys = [hostSecrets.keys.ssh-initramfs.ed25519];
    };
  };
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.version = 2;

  fileSystems = let
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
    "/boot".device = "/dev/disk/by-uuid/${uuids.boot}";

    "/"        = mainSubvol "rootfs"  [];
    "/var"     = mainSubvol "var"     ["autodefrag"];
    "/nix"     = mainSubvol "nix"     ["autodefrag" "noatime" "nodatacow"];
    "/home"    = mainSubvol "home"    ["autodefrag"];
    "/keyring" = mainSubvol "keyring" ["autodefrag"];

    "/var/.snapshots"     = snapshotSubvol "var"     ["autodefrag"];
    "/home/.snapshots"    = snapshotSubvol "home"    [];
    "/keyring/.snapshots" = snapshotSubvol "keyring" [];

    "/mnt/root-btrfs" = fromSubvol "/" ["nodatacow" "noatime" "noexec"];
  };

  networking.defaultGateway.address = "5.255.96.1";
  networking.defaultGateway6.address = "2a04:52c0:101::1";
  networking.interfaces.ens3.ipv4.addresses = [{
    address = "5.255.96.101";
    prefixLength = 24;
  }];
  networking.interfaces.ens3.ipv6.addresses = [{
    address = "2a04:52c0:101:2a7::101";
    prefixLength = 64;
  }];
  networking.interfaces.ens3.ipv6.routes = [{
    address = "2a04:52c0:101::1";
    prefixLength = 128;
  }];

  # Piggy-back into the network-interfaces-systemd implementation to fix
  # missing implementation of routes.
  systemd.network.networks."40-ens3".routes = [{
    routeConfig.Destination = "2a04:52c0:101::1";
  }{
    routeConfig.Destination = "0.0.0.0/0";
    routeConfig.Gateway = "5.255.96.1";
  }{
    routeConfig.Destination = "::/0";
    routeConfig.Gateway = "2a04:52c0:101::1";
  }];

  services.snapper.configs = let
    mkCfg = path: {
      subvolume = path;
      extraConfig = ''
        ALLOW_GROUPS="wheel"
        EMPTY_PRE_POST_CLEANUP="yes"
        SYNC_ACL="yes"
        TIMELINE_CLEANUP="yes"
        TIMELINE_CREATE="yes"
      '';
    };
  in {
    "home"    = mkCfg "/home";
    "keyring" = mkCfg "/keyring";
    "var"     = mkCfg "/var";
  };
  swapDevices = [];
}
