{ config, pkgs, lib, ... }: with lib; {
  options.roos.hyprland.enable = mkEnableOption "Enable Hyprland support.";

  config = mkIf config.roos.hyprland.enable {
    fonts.fonts = with pkgs; [ font-awesome noto-fonts-emoji ];

    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass.override { waylandSupport = true; };
    };

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

    services.greetd.enable = true;
    services.greetd.settings.hyprland.command =
      "${lib.makeBinPath [pkgs.greetd.tuigreet]}/tuigreet --time --cmd Hyprland";
    services.pipewire.enable = true;
  };
}
