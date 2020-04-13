{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.wayland.enable = mkEnableOption "Enable wayland support.";

  config = mkIf config.roos.wayland.enable {
    nixpkgs.config.packageOverrides = pkgs: {
      pass = pkgs.pass.override { waylandSupport = true; };
    };

    roos.gConfig = {
      home.sessionVariables = {
        MOZ_ENABLE_WAYLAND = 1;
        QT_QPA_PLATFORM = "wayland-egl";
      };
      home.packages = with pkgs; [ sway mako slurp grim ];
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
  };
}
