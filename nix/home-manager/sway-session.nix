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

  waybar' = with pkgs; let
    cfgFile = dotfileUtils.fetchDotfile "etc/waybar/config";
    styleFile = dotfileUtils.fetchDotfile "etc/waybar/style.css";
  in stdenv.mkDerivation {
    name = "waybar-with-config";
    version = waybar.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${waybar}/bin/waybar "$out/bin/waybar" \
        --add-flags "--config ${cfgFile} --style ${styleFile}"
    '';
  };

  swaylock' = with pkgs; stdenv.mkDerivation {
    name = "swaylock-wrapped";
    version = swaylock-effects.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${swaylock-effects}/bin/swaylock "$out/bin/swaylock" \
        --add-flags "--screenshots --clock --effect-blur 7x5" \
        --add-flags "--effect-vignette 0.5:0.5 --fade-in 0.25"
    '';
  };
in {
  options.sessions.sway.enable = mkEnableOption "Sway-based wayland session";

  config = mkIf config.sessions.sway.enable {
    gtk.enable = true;
    gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true;

    qt.enable = true;
    qt.platformTheme = "gnome";
    qt.style.name = "adwaita-dark";
    qt.style.package = pkgs.adwaita-qt;

    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface".color-scheme = "prefer-dark";
        "org/gnome/desktop/peripherals/touchpad".tap-to-click = true;
        "org/gnome/desktop/peripherals/touchpad".two-finger-scrolling = true;
      };
    };

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland-egl";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = 1;
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = 1;
    };

    home.packages = with pkgs; [
      slurp grim swappy waybar' dmenu libnotify swaylock' swayidle
      wdisplays wl-clipboard wl-clipboard-x11 mpc_cli pavucontrol
      pinentry' x11_ssh_askpass
      adwaita-qt pulseaudio wireplumber wayvnc
    ];

    programs.foot.enable = true;
    programs.foot.settings.main = {
      font = "monospace:size=9";
      dpi-aware = true;
    };
    programs.sway.roos-cfg.enable = true;
    programs.swaync.enable = true;

    roos.media.enable = true;
    wayland.windowManager.sway.enable = true;

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

    systemd.user.services.waybar = {
      Unit.Description = "A wayland taskbar";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${waybar'}/bin/waybar";
        Restart = "always";
        RestartSec = "3";
      };
    };
  };
}
