{ config, lib, ... }: with lib; {
  options.roos.cosmic.enable = mkEnableOption "Enable Cosmic support.";

  config = mkIf config.roos.cosmic.enable {
    environment.sessionVariables = {
      # Under wayland, access to the clipboard requires a window to be focused.
      # With this, cosmic will enable the wlr data control protocol, enabling
      # support for clipboard managers.
      # https://github.com/lilyinstarlight/nixos-cosmic?tab=readme-ov-file#cosmic-utilities---clipboard-manager-not-working
      COSMIC_DATA_CONTROL_ENABLED = "1";
    };

    services.desktopManager.cosmic.enable = true;
    services.flatpak.enable = true;
    services.gnome.gnome-keyring.enable = true;

    roos.gConfig.config = {
      session.wayland.enable = true;
    };
    roos.wayland.enable = true;
  };
}
