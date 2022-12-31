{ config, pkgs, lib, ... }: with lib; {
  options.roos.hyprland.enable = mkEnableOption "Enable Hyprland support.";

  config = mkIf config.roos.hyprland.enable {
    programs.hyprland.enable = true;

    roos.gConfig.config = {
      sessions.hyprland.enable = true;
      # Allocate a target so other automation can depend on it.
      systemd.user.targets."hyprland-session" = {
        Target = {};
        Unit.PartOf = [ "graphical-session.target" ];
        # This target is started by hyprland
      };
    };
    roos.wayland.enable = true;
  };
}
