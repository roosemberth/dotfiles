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
in {
  options.sessions.sway.enable = mkEnableOption "Sway-based wayland session";

  config = mkIf config.sessions.sway.enable {
    home.packages = with pkgs; [ waybar' dmenu ];

    programs.sway.roos-cfg.enable = true;
    programs.swaync.enable = true;

    session.wayland.enable = true;
    session.wayland.swayidle.enable = true;
    systemd.user.targets.sway-session = {
      Unit.After = "graphical-session-pre.target";
      Unit.BindsTo = "graphical-session.target";
      Unit.Wants = "graphical-session-pre.target";
    };
    systemd.user.services.waybar = {
      Unit.Description = "A wayland taskbar";
      Unit.PartOf = [ "sway-session.target" ];
      Install.WantedBy = [ "sway-session.target" ];
      Service = {
        ExecStart = "${waybar'}/bin/waybar";
        Restart = "always";
        RestartSec = "3";
      };
    };

    wayland.windowManager.sway.enable = true;
  };
}
