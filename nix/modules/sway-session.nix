{ config, pkgs, lib, ... }: with lib; {
  options.roos.sway.enable = mkEnableOption "Enable sway support.";

  config = mkIf config.roos.sway.enable {
    fonts.fonts = with pkgs; [ font-awesome noto-fonts-emoji ];

    i18n.inputMethod = {
      enabled = "ibus";
      ibus.engines = with pkgs.ibus-engines; let
        typing-booster' = typing-booster.override {
          langs = [ "de-ch" "en-us" "es-sv" "fr-moderne" "it-it" "ru-ru" ];
        };
      in [ typing-booster' ];
    };

    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass-wayland;
    };

    programs.sway.enable = true;
    programs.sway.extraPackages = [];  # Managed by sway-session.nix
    programs.sway.wrapperFeatures.gtk = true;
    programs.sway.extraSessionCommands = ''
      export MOZ_ENABLE_WAYLAND=1
      export MOZ_USE_XINPUT2=1
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=sway
    '';

    roos.gConfig.config = {
      home.packages = with pkgs; [ gammastep ];
      sessions.sway.enable = true;
      # Allocate sway-session target so other automation can depend on it.
      systemd.user.targets."sway-session" = {
        Target = {};
        Unit.PartOf = [ "graphical-session.target" ];
        # This target is started by sway
      };
    };

    services.greetd.enable = true;
    services.greetd.settings.default_session.command =
      "${lib.makeBinPath [pkgs.greetd.tuigreet]}/tuigreet --time --cmd sway";
    services.pipewire.enable = true;

    xdg.portal.enable = true;
  };
}
