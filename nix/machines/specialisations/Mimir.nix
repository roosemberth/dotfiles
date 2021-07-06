{ config, pkgs, lib, secrets, ... }:
{
  specialisation.tmpgnome.inheritParentConfig = true;
  specialisation.tmpgnome.configuration = {
    users.users.foo.isNormalUser = true;
    users.users.foo.password = secrets.users.foo.password;
    users.users.foo.extraGroups = [ "input" "video" ];
    users.users.foo.shell = pkgs.zsh;
    services.xserver.enable = true;
    services.xserver.desktopManager.gnome3.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.autorun = false;
    services.xserver.displayManager.sessionCommands =
      "setxkbmap us intl -option caps:escape";
    roos.user-profiles.graphical = ["foo"];
  };
}
