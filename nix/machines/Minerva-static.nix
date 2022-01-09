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
      network.ssh.hostKeys = [
        "/run/secrets/ssh-host/initramfs/ecdsa"
        "/run/secrets/ssh-host/initramfs/ed25519"
      ];
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

  sops.secrets."ssh-host/initramfs/ed25519" = {};
  sops.secrets."ssh-host/initramfs/ecdsa" = {};

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

  roos.btrbk.enable = true;
  roos.btrbk.config = {
    snapshot_preserve = "10h 7d 4w 6m";
    snapshot_preserve_min = "1h";
    timestamp_format = "long";

    volumes."/mnt/root-btrfs/subvolumes" = {
      subvolumes = [ "active/rootfs" "active/home" "active/var" ];
      snapshot_dir = "snapshots";
    };
  };

  services.udev.packages = with lib; let
    exprOpts = defOp: { name, ... }: {
      options.name = mkOption { type = types.str; default = name; };
      options.value = mkOption { type = types.str; };
      options.operator = mkOption {
        type = types.enum [ "==" "!=" "=" "+=" "-=" ":=" ];
        default = defOp;
      };
    };

    ruleOpts = { config, ... }: {
      options.match = mkOption {
        description = "Attrset with expressions to match an event.";
        default = {};
        type = with types; let
          asValue = (s: { value = s; });
        in attrsOf (coercedTo str asValue (submodule (exprOpts "==")));
      };
      options.make = mkOption {
        description = "Attrset with expressions to apply an action.";
        default = {};
        type = with types; let
          asValue = s: { value = s; };
        in attrsOf (coercedTo str asValue (submodule (exprOpts "=")));
      };
      options.ruleStr = mkOption {
        default = concatMapStringsSep ", "
          (v: "${v.name}${v.operator}\"${v.value}\"")
          (attrValues config.match ++ attrValues config.make);
      };
    };

    renderRule =
      cfg: (evalModules { modules = [ ruleOpts cfg ]; }).config.ruleStr;

    devpathToBay = {
      "*.3.4" = "1";
      "*.3.3" = "2";
      "*.3.2" = "3";
      "*.3.1" = "4";
      "*.4.4" = "5";
      "*.4.3" = "6";
      "*.4.2" = "7";
      "*.4.1" = "8";
    };

    usbSetEnvRules = attrValues (mapAttrs (devpath: bay: {
      config = {
        match."SUBSYSTEMS"      = "usb";
        match."ATTRS{product}"  = "QNAP";
        match."KERNELS"         = "${devpath}";
        make."ENV{QNAP_BAY_ID}" = bay;
      };
    }) devpathToBay);

    renameBlocksRules = map (n: {
      config = {
        match."SUBSYSTEM"        = "block";
        match."KERNEL"           = "sd[a-z]";
        match."ENV{QNAP_BAY_ID}" = n;
        make."SYMLINK"           = { operator = "+="; value = "qnap-bay${n}"; };
        make."ENV{NAS_DISK_IDX}" = n;
      };
    }) (attrValues devpathToBay);
  in lib.toList (pkgs.writeTextFile {
      name = "nas-udev-rules";
      destination = "/etc/udev/rules.d/140-match-nas-bays.rules";
      text = ''
        # Rules to rename QNAP drive bays
        ${concatMapStringsSep "\n" renderRule usbSetEnvRules}
        ${concatMapStringsSep "\n" renderRule renameBlocksRules}
      '';
    });
}
