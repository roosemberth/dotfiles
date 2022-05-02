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

    roos.actions."notifs:open" =
      "${pkgs.swaynotificationcenter}/bin/swaync-client --open-panel";
    roos.actions."notifs:close" =
      "${pkgs.swaynotificationcenter}/bin/swaync-client --close-panel";
    roos.actions."notifs:toggle" =
      "${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-dnd";
  };
}
