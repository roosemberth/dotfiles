{ config, pkgs, lib, ... }: with lib; {
  options.roos.sway.enable = mkEnableOption "Enable sway support.";

  config = mkIf config.roos.sway.enable {
    fonts.fonts = [ pkgs.font-awesome ];
    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass.override { waylandSupport = true; };
    };

    roos.gConfig.config = {
      sessions.sway.enable = true;
      # Allocate sway-session target so other automation can depend on it.
      systemd.user.targets."sway-session" = {
        Target = {};
        Unit.PartOf = [ "graphical-session.target" ];
        # This target is started by sway
      };
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

    xdg.portal.enable = true;
    xdg.portal.gtkUsePortal = true;

    services.pipewire.enable = true;
    services.greetd.enable = true;
    services.greetd.settings.default_session.command =
      "${lib.makeBinPath [pkgs.greetd.tuigreet]}/tuigreet --time --cmd sway";
  };
}
