{ pkgs, config, lib, ... }: with lib; let
  cfg = config.programs.swaync;
in {
  options.programs.swaync.enable = mkEnableOption "Notification center for sway";
  config = mkIf cfg.enable {
    home.packages = [ pkgs.swaynotificationcenter ];

    systemd.user.services.swaync = {
      Unit.Description = "Notifications center for sway";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
        Restart = "always";
        RestartSec = "3";
      };
    };
  };
}
