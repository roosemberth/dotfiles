{ config, lib, pkgs,  ... }: with lib; {
  options.sessions.hyprland.enable = mkEnableOption "Hyprland wayland session";

  config = mkIf config.sessions.hyprland.enable {
    session.wayland.enable = true;

    wayland.windowManager.hyprland = let
      terminal = "${pkgs.foot}/bin/foot";
    in {
      enable = true;
      extraConfig = ''
        bind=SUPER,RETURN,exec,${terminal}
      '';
    };
  };
}
