{ config, pkgs, lib, ... }:

with lib;
{
  options.roos.x11.enable = mkEnableOption "Roos' x11 config";

  config = mkIf config.roos.x11.enable {
    services.xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "intl";

      # Enable touchpad support.
      libinput.enable = true;

      displayManager.sessionCommands = ''
        . $HOME/dotfiles/sh_environment
        . $XDG_CONFIG_HOME/sh/profile
        export XDG_CURRENT_DESKTOP=GNOME
        ${pkgs.nitrogen}/bin/nitrogen --set-auto background-images/venice.png
        ${pkgs.xcape}/bin/xcape -e 'Shift_L=Escape'
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap us intl -option caps:escape -option shift:both_capslock
        ${pkgs.xorg.xrdb}/bin/xrdb $XDG_CONFIG_HOME/X11/Xresources
        ${pkgs.xss-lock}/bin/xss-lock ${pkgs.xtrlock-pam}/bin/xtrlock-pam &!
      '';

      displayManager.slim.enable = true;
      displayManager.slim.defaultUser = "roosemberth";
      windowManager.xmonad.enable = true;
      windowManager.default = "xmonad";
      windowManager.xmonad.extraPackages =
        haskellPackages: with haskellPackages; [xmonad-contrib xmonad-extras];
      desktopManager.default = "none";
      desktopManager.gnome3.enable = true;
      desktopManager.gnome3.debug = true;
    };
  };
}
