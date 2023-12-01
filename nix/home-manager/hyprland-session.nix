{ config, lib, pkgs, dotfileUtils, ... }: with lib; let
  waybar' = with pkgs; let
    cfgFile = dotfileUtils.fetchDotfile "etc/waybar/config";
    styleFile = dotfileUtils.fetchDotfile "etc/waybar/style.css";
    hyprland' = config.wayland.windowManager.hyprland.finalPackage;
  in stdenv.mkDerivation {
    name = "waybar-hyprland-with-config";
    version = waybar.version;
    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      makeWrapper ${waybar}/bin/waybar "$out/bin/waybar" \
        --prefix PATH : "${lib.makeBinPath [ hyprland' pavucontrol procps ]}" \
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
      '';
      settings = {
        "$MOUSE_LMB" = "mouse:272";
        "$MOUSE_RMB" = "mouse:273";
        "$MOUSE_MMB" = "mouse:274";

        input = {
          kb_options = "caps:escape";
          kb_variant = "intl";
          repeat_rate = 50;
          repeat_delay = 240;
          touchpad.clickfinger_behavior = 1;
        };
        general = {
          "col.active_border" = "0xFF155aef";
          "col.inactive_border" = "0xFF222222";
        };
        gestures = {
          workspace_swipe = true;
          workspace_swipe_min_speed_to_force = 5;
        };
        decoration = {
          rounding = 10;
          inactive_opacity = 0.9;
          blur.enabled = true;
          blur.xray = true;
        };
        binds.workspace_back_and_forth = true;
        dwindle.no_gaps_when_only = true;

        bindm = [
          "SUPER,$MOUSE_LMB,movewindow"
          "SUPER,$MOUSE_RMB,resizewindow"
        ];

        bind = [
          "SUPER,RETURN,exec,foot -e tmux"
          "SUPERCONTROL,RETURN,exec,action exec:launcher:open"
          "SUPER,f,fullscreen,0"
          "SUPER,SPACE,fullscreen,1"
          "SUPERSHIFT,f,togglefloating"
          "SUPER,F4,killactive"
          "SUPERCONTROLSHIFT,F4,exit"

          "SUPER,Print,exec,grim -g \"$(slurp)\" - | swappy -f -"

          "SUPER,1,workspace,1"
          "SUPER,2,workspace,2"
          "SUPER,3,workspace,3"
          "SUPER,4,workspace,4"
          "SUPER,5,workspace,5"
          "SUPER,6,workspace,6"
          "SUPER,7,workspace,7"
          "SUPER,8,workspace,8"
          "SUPER,9,workspace,9"
          "SUPER,0,workspace,0"

          "SUPERSHIFT,1,movetoworkspacesilent,1"
          "SUPERSHIFT,2,movetoworkspacesilent,2"
          "SUPERSHIFT,3,movetoworkspacesilent,3"
          "SUPERSHIFT,4,movetoworkspacesilent,4"
          "SUPERSHIFT,5,movetoworkspacesilent,5"
          "SUPERSHIFT,6,movetoworkspacesilent,6"
          "SUPERSHIFT,7,movetoworkspacesilent,7"
          "SUPERSHIFT,8,movetoworkspacesilent,8"
          "SUPERSHIFT,9,movetoworkspacesilent,9"
          "SUPERSHIFT,0,movetoworkspacesilent,10"

          # Moving around
          "SUPER,h,movefocus,l"
          "SUPER,l,movefocus,r"
          "SUPER,k,movefocus,u"
          "SUPER,j,movefocus,d"

          "SUPERSHIFT,h,movewindow,l"
          "SUPERSHIFT,l,movewindow,r"
          "SUPERSHIFT,k,movewindow,u"
          "SUPERSHIFT,j,movewindow,d"

          "SUPER,left,resizeactive,-40 0"
          "SUPER,right,resizeactive,40 0"
          "SUPER,up,resizeactive,0 -40"
          "SUPER,down,resizeactive,0 40"

          "SUPERCONTROL,space,layoutmsg,swapwithmaster"
          "SUPERCONTROL,i,layoutmsg,addmaster"
          "SUPERCONTROL,o,layoutmsg,removemaster"
          "SUPER,=,layoutmsg,addmaster"
          "SUPER,-,layoutmsg,addmaster"

          "SUPERCONTROL,space,togglegroup"
          "SUPERCONTROL,l,changegroupactive,f"
          "SUPERCONTROL,h,changegroupactive,b"

          "SUPERCONTROL,Backspace,movetoworkspace,special"
          "SUPER,Backspace,togglespecialworkspace"

          # Scratchpad
          "SUPER,q,exec,tmux detach-client -s flyway"
          "SUPERSHIFT,q,exec,action exec:term:open-scratchpad"

          # Handy stuff
          "SUPERCONTROL,f,exec,firefox"
          "SUPER,p,exec,passmenu"
          "SUPER,v,exec,action exec:mpv:clipboard"
          ",XF86Display,exec,sm -i"
          ",XF86Tools,exec,action notifs:open"

          ",XF86Favorites,exec,systemd-inhibit --what=idle:sleep:handle-lid-switch swaylock"
        ];

        bindle = [
          # Hardware control
          ",XF86MonBrightnessDown,exec,brightnessctl s 5%-"
          "SHIFT,XF86MonBrightnessDown,exec,brightnessctl s 1"
          ",XF86MonBrightnessUp,exec,brightnessctl s 5%+"
          "SHIFT,XF86MonBrightnessUp,exec,brightnessctl s 100%"

          "SUPER,Delete,exec,action player:play-pause"
          "SUPER,End,exec,action player:prev"
          "SUPER,Insert,exec,action player:next"
          "SUPER,XF86AudioLowerVolume,exec,action player:prev"
          "SUPER,XF86AudioRaiseVolume,exec,action player:next"

          ",XF86AudioMute,exec,action audio:vol-mute"
          ",XF86AudioLowerVolume,exec,action audio:vol-down"
          ",XF86AudioRaiseVolume,exec,action audio:vol-up"
          ",XF86AudioPrev,exec,action player:Prev"
          ",XF86AudioNext,exec,action player:next"
          ",XF86AudioPlay,exec,action player:play-pause"
          ",XF86AudioStop,exec,action player:play-pause"
        ];

        windowrulev2 = [
          "float,class:launcher"
          "noanim,class:launcher"
          "float,class:Scratchpad-flyway"
          "noanim,class:Scratchpad-flyway"
          "opacity 0.9,class:Scratchpad-flyway"
          "size 50% 60%,class:Scratchpad-flyway"
          "dimaround,class:Scratchpad-flyway"
          "center,class:Scratchpad-flyway"
          "float,title:^(About Mozilla Firefox)$"
          "float,title:^(Firefox — Sharing Indicator)$"
          "move 50% 10,title:^(Firefox — Sharing Indicator)$"
        ];
      };
    };
  };
}
