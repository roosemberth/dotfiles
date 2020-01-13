{ config, pkgs, lib, ... }:
{
  imports = [../modules];

  boot.loader.grub.device = "nodev";
  environment.systemPackages = (with pkgs; [ vim curl htop alacritty cacert ]);
  fileSystems."/".device = "/dev/sda";
  i18n.consoleFont = "sun12x22";

  networking.hostName = "test-ly"; # Define your hostname.

  security.pam.loginLimits = [{
    domain = "*"; item = "core"; type = "-"; value = "-1";
  }];
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  services.xserver = {
    enable = true;
    displayManager.ly.enable = true;
    displayManager.ly.defaultUser = "roos";
    displayManager.ly.defaultSessionIndex = 4;
    windowManager.xmonad.enable = true;
    windowManager.default = "xmonad";
    desktopManager.default = "none";
  };
  services.journald.console = "/dev/ttyS0";
  services.mingetty.autologinUser = "roos";

  system.stateVersion = "19.09";
  systemd.coredump.enable = true;

  users.mutableUsers = false;
  users.extraUsers.roos = {
    password = "roos";
    isNormalUser = true;
    extraGroups = ["wheel" "tty" "video" "input"];
  };
}
