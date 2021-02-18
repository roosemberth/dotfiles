{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
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
  options.roos.sway.enable = mkEnableOption "Enable sway support.";

  config = mkIf config.roos.sway.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass.override { waylandSupport = true; };
    };

    roos.gConfig = {
      gtk.enable = true;
      gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      home.sessionVariables = {
        MOZ_ENABLE_WAYLAND = 1;
        QT_QPA_PLATFORM = "wayland-egl";
      };
      home.packages = with pkgs; [
        mako slurp grim wdisplays wl-clipboard wl-clipboard-x11
        pinentry' firefox epiphany x11_ssh_askpass
      ];
      xdg.configFile."mako/config".source = util.fetchDotfile "etc/mako/config";
      xdg.configFile."sway/config".source = util.fetchDotfile "etc/sway/config";

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
    };

    programs.sway.enable = true;
  };
}
