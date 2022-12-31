{ config, pkgs, lib, ... }: with lib; let
  cfg = config.roos.wayland;
in {
  options.roos.wayland.enable = mkEnableOption "Enable wayland support";

  config = mkIf cfg.enable {
    fonts.fonts = with pkgs; [ font-awesome noto-fonts-emoji ];

    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass-wayland;
    };

    roos.gConfig.config.home.packages = with pkgs; [ gammastep ];

    services.greetd.enable = true;
    services.greetd.settings.default_session.command = let
      binpath = lib.makeBinPath [pkgs.greetd.tuigreet];
      sessionsDir = "/run/current-system/sw/share/wayland-sessions";
    in "${binpath}/tuigreet --sessions ${sessionsDir} --time";
    services.pipewire.enable = true;

    xdg.portal.enable = true;
  };
}
