{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.wayland.enable = mkEnableOption "Enable wayland support.";

  config = mkIf config.roos.wayland.enable {
    roos.gConfig = {
      home.sessionVariables = {
        MOZ_ENABLE_WAYLAND = 1;
        QT_QPA_PLATFORM = "wayland-egl";
      };
      home.packages = with pkgs; [ mako ];
      xdg.configFile."".source = util.fetchDotfile "local/etc/mako/config";
    };
  };
}
