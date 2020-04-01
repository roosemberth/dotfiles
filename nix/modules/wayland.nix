{ config, pkgs, lib, ... }: with lib;
{
  options.roos.wayland.enable = mkEnableOption "Enable wayland support.";

  config = mkIf config.roos.wayland.enable {
    roos.gConfig.home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland-egl";
    };
  };
}
