{ pkgs, config, lib, dotfileUtils, ... }: with lib; let
  waybar' = with pkgs; let
    cfgFile = dotfileUtils.fetchDotfile "etc/waybar/config";
    styleFile = dotfileUtils.fetchDotfile "etc/waybar/style.css";
  in stdenv.mkDerivation {
    name = "waybar-with-config";
    version = waybar.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${waybar}/bin/waybar "$out/bin/waybar" \
        --add-flags "--config ${cfgFile} --style ${styleFile}"
    '';
  };

  swaylock' = with pkgs; stdenv.mkDerivation {
    name = "swaylock-wrapped";
    version = swaylock-effects.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${swaylock-effects}/bin/swaylock "$out/bin/swaylock" \
        --add-flags "--screenshots --clock --effect-blur 7x5" \
        --add-flags "--effect-vignette 0.5:0.5 --fade-in 0.25"
    '';
  };
in {
  options.sessions.sway.enable = mkEnableOption "Sway-based wayland session";

  config = mkIf config.sessions.sway.enable {
    home.packages = with pkgs; [
      waybar' dmenu swaylock' swayidle
    ];

    programs.sway.roos-cfg.enable = true;
    programs.swaync.enable = true;

    session.wayland.enable = true;
    systemd.user.services.waybar = {
      Unit.Description = "A wayland taskbar";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${waybar'}/bin/waybar";
        Restart = "always";
        RestartSec = "3";
      };
    };

    wayland.windowManager.sway.enable = true;
  };
}
