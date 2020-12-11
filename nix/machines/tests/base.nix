{ config, lib, pkgs, secrets, ... }:
{
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  fileSystems."/boot" = { fsType = "vfat"; device = "/dev/sda1"; };
  fileSystems."/".device = "/dev/sda2";

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.journald.console = "/dev/ttyS0";
  services.mingetty.autologinUser = "roos";
  systemd.coredump.enable = true;
  security.pam.loginLimits = [{
    domain = "*"; item = "core"; type = "-"; value = "-1";
  }];

  users.mutableUsers = false;
  users.extraUsers.roos.password = "roos";
  users.extraUsers.roos.isNormalUser = true;
  users.extraUsers.roos.extraGroups = ["wheel"];
}
