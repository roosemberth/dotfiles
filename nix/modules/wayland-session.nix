{ config, pkgs, lib, ... }: with lib; let
  cfg = config.roos.wayland;
in {
  options.roos.wayland.enable = mkEnableOption "Enable wayland support";

  config = mkIf cfg.enable {
    # Make wayland sessions visible.
    environment.pathsToLink = [ "/share/wayland-sessions" ];

    fonts.packages = with pkgs; [ font-awesome noto-fonts-emoji ];

    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass-wayland;
      # GNOME desktop portal causes havoc since it will not run without
      # gnome-shell, but applications will still try to call it over d-bus.
      # See https://github.com/flatpak/xdg-desktop-portal/issues/906
      xdg-desktop-portal-gnome = pkgs.symlinkJoin {
        name = "xdg-desktop-portal-gnome";
        paths = [ pkgs.xdg-desktop-portal-gnome ];
        postBuild = ''
          rm $out/share/xdg-desktop-portal/portals/gnome.portal
        '';
      };
    };

    roos.gConfig.config.home.packages = with pkgs; [ gammastep ];

    services.greetd.enable = true;
    services.greetd.settings.default_session.command = let
      binpath = lib.makeBinPath [pkgs.tuigreet];
      sessionsDir = "/run/current-system/sw/share/wayland-sessions";
    in "${binpath}/tuigreet --sessions ${sessionsDir} --time";
    services.pipewire.enable = true;

    xdg.portal.enable = true;
  };
}
