{ pkgs, config, lib, dotfileUtils, ... }: with lib; let
  pinentry' = let
    # Disable GNOME secrets integration...
    mypinentry = pkgs.pinentry.override({ libsecret = null; });
    pinentry-curses = getOutput "curses" mypinentry;
    pinentry-gtk2   = getOutput "gtk2"   mypinentry;
  in pkgs.writeShellScriptBin "pinentry" ''
    if [[ "$XDG_SESSION_TYPE" == "wayland" || "$XDG_SESSION_TYPE" = "x11" ]]; then
      exec ${pinentry-gtk2}/bin/pinentry-gtk-2 "$@"
    else
      ${pkgs.ncurses}/bin/reset
      exec ${pinentry-curses}/bin/pinentry-curses "$@"
    fi
  '';
in {
  options.sessions.sway.enable = mkEnableOption "Sway-based wayland session";

  config = mkIf config.sessions.sway.enable {
    gtk.enable = true;
    gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;

    qt.enable = true;
    qt.platformTheme = "gtk";
    qt.style.name = "adwaita-dark";

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland-egl";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = 1;
    };
    home.packages = with pkgs; [
      mako slurp grim wdisplays wl-clipboard wl-clipboard-x11
      pinentry' firefox-wayland epiphany x11_ssh_askpass
      adwaita-qt pulseaudio wireplumber remap-pa-client
      wayvnc
    ];
    xdg.configFile."mako/config".source =
      dotfileUtils.fetchDotfile "etc/mako/config";
    xdg.configFile."sway/config".source =
      dotfileUtils.fetchDotfile "etc/sway/config";

    systemd.user.services.ssh-agent = {
      Unit.Description = "SSH Agent";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -D -a %t/ssh-agent-%u-socket";
        Restart = "always";
        RestartSec = "3";
        Environment = [ "SSH_ASKPASS=${pkgs.x11_ssh_askpass}/libexec/ssh-askpass" ];
      };
    };
    systemd.user.services.polkit = {
      Unit.Description = "Polkit graphical client";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "always";
        RestartSec = "3";
      };
    };
  };
}
