{ config, lib, pkgs, dotfileUtils, ... }: with lib; let
  waybar' = with pkgs; let
    cfgFile = dotfileUtils.fetchDotfile "etc/waybar/config";
    styleFile = dotfileUtils.fetchDotfile "etc/waybar/style.css";
  in stdenv.mkDerivation {
    name = "waybar-hyprland-with-config";
    version = waybar-hyprland.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${waybar-hyprland}/bin/waybar "$out/bin/waybar" \
        --prefix PATH : "${lib.makeBinPath [ hyprland pavucontrol procps ]}" \
        --add-flags "--config ${cfgFile} --style ${styleFile}"
    '';
  };

in {
  options.sessions.hyprland.enable = mkEnableOption "Hyprland wayland session";

  config = mkIf config.sessions.hyprland.enable {
    home.packages = [ config.roos.actions-package ];

    programs.swaync.enable = true;

    session.wayland.enable = true;
    session.wayland.swayidle.enable = true;
    systemd.user.services.waybar-hyprland = {
      Unit.Description = "A wayland taskbar for hyprland";
      Unit.PartOf = [ "hyprland-session.target" ];
      Install.WantedBy = [ "hyprland-session.target" ];
      Service = {
        ExecStart = "${waybar'}/bin/waybar";
        Restart = "always";
        RestartSec = "3";
      };
    };
    home.activation.hyprlandConfigWorkaround = let
      home = config.home.homeDirectory;
    in hm.dag.entryAfter ["linkGeneration"] ''
      # There seems to be no reliable way to specify a custom configuration path.
      # Symlink this as a hack in the meantime...
      mkdir -p ${home}/.config/hypr
      rm -f ${home}/.config/hypr/hyprland.conf
      ln -s ${home}/.local/etc/hypr/hyprland.conf ${home}/.config/hypr/hyprland.conf
    '';

    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = ''
        exec-once=${pkgs.writeShellScript "import-user-env-to-dbus-systemd" ''
          if [ -d "/etc/profiles/per-user/$USER/etc/profile.d" ]; then
            . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
          fi
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
            XDG_CONFIG_HOME XDG_DATA_HOME XDG_BACKEND
        ''}
        ${builtins.readFile (dotfileUtils.fetchDotfile "etc/hyprland.conf")}
      '';
    };
  };
}
