{ config, pkgs, lib, ... }:
let
  taffy = pkgs.callPackage /Storage/DevelHub/8-Repositories/taffy-roos/live {};
in
with lib;
{
  options.roos.x11.enable = mkEnableOption "Roos' x11 config";

  config = mkIf config.roos.x11.enable {
    hardware = {
      bumblebee.enable = true;
      bumblebee.connectDisplay = true;
      bumblebee.driver = "nvidia";
      bumblebee.pmMethod = "bbswitch";

      opengl.enable = true;
      opengl.driSupport = true;
      opengl.driSupport32Bit = true;
    };

    location.provider = "geoclue2";

    roos.xUserConfig.systemd.user.services =
    let
      xServices = {
        taffy = {
          Unit.Description = "Taffybar";
          Service.ExecStart = "${taffy}/bin/taffybar";
        };
        screen-locker = {
          Unit.Description = "Screen-locking daemon";
          Service.ExecStart = "${pkgs.xss-lock}/bin/xss-lock -- ${pkgs.xtrlock-pam}/bin/xtrlock-pam -b none";
        };
      };
    in lib.mapAttrs
      (name: srvDesc: lib.recursiveUpdate srvDesc
       { Unit.After = [ "graphical-session-pre.target" ];
         Unit.PartOf = [ "graphical-session.target" ];
       }
      ) xServices;

    services = {
      redshift.enable = true;

      gnome3.core-os-services.enable = true;
      gnome3.core-shell.enable = true;
      gnome3.core-utilities.enable = mkDefault true;

      xserver = {
        enable = true;
        layout = "us";
        xkbVariant = "intl";

        libinput.enable = true;  # Enable touchpad support.

        displayManager.sessionCommands = ''
          . $HOME/dotfiles/sh_environment
          . $XDG_CONFIG_HOME/sh/profile
          export XDG_CURRENT_DESKTOP=GNOME
          ${pkgs.xcape}/bin/xcape -e 'Shift_L=Escape'
          ${pkgs.xorg.setxkbmap}/bin/setxkbmap us intl -option caps:escape
          ${pkgs.xorg.xrdb}/bin/xrdb $XDG_CONFIG_HOME/X11/Xresources
          ${pkgs.systemd}/bin/systemctl --user start random-background
        '';

        displayManager.sddm.enable = true;
        displayManager.sddm.enableHidpi = true;
        windowManager.xmonad.enable = true;
        windowManager.default = "xmonad";
        windowManager.xmonad.extraPackages =
          haskellPackages: with haskellPackages; [xmonad-contrib xmonad-extras taffy];
        desktopManager.default = "none";
        desktopManager.gnome3.enable = true;

        videoDrivers = ["intel"];
      };
    };
  };
}
