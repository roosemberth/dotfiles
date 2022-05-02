{ config, lib, pkgs, ... }: with lib; let
in {
  options.programs.sway.roos-cfg.enable = mkEnableOption "Roos' config for sway";

  config.wayland.windowManager.sway = let
    cfg = config.wayland.windowManager.sway;
    mod = cfg.config.modifier;
    term = cfg.config.terminal;
    lockcmd = "swaylock -c 00000050";
    selectWs = "swaymsg -t get_workspaces | jq 'map(.name)|.[]' | dmenu";
    actions = config.roos.actions;
  in mkIf config.programs.sway.roos-cfg.enable {
    config = {
      bars = [];

      modifier = "Mod4";
      terminal = "${pkgs.foot}/bin/foot";

      keybindings = {
        # Session
        "${mod}+F4"                    = "kill";
        "${mod}+c+Control"             = "reload";
        "${mod}+mod1+Control+F4+Shift" = "exec swaymsg exit";
        "${mod}+t+Control" = ''
          exec tmux list-sessions \
          | grep -v flyway | grep -oP '^[^:]+(?!.*attached)' \
          | xargs -n1 setsid ${term} -e tmux attach -t
        '';
        "${mod}+Print" = ''
          exec swaymsg -t get_tree \
          | jq -r '.. | select(.pid? and .visible?)| .rect \
                  | "\(.x),\(.y) \(.width)x\(.height)"' \
          | slurp | grim -g - - | swappy -f -
        '';

        # Apps
        "${mod}+f+Control"    = "exec firefox";
        "${mod}+p"            = "exec passmenu";
        "${mod}+m"            = "exec makoctl dismiss";
        "${mod}+Return"       = "exec ${term} -e tmux";
        "${mod}+Return+Shift" = "exec ${term}";
        "${mod}+v"            = ''
          exec mpv "$(wl-paste)" --load-unsafe-playlists \
            --script-opts=try_ytdl_first=yes \
            --ytdl-format='bestvideo[height<=?1080]+bestaudio/best'
        '';
        "${mod}+XF86AudioMute" = ''
          exec ${pkgs.remap-pa-client}/bin/remap-pa-client
        '';

        # Layout management
        "${mod}+a+Shift" = "focus parent";
        "${mod}+w"       = "splitv";
        "${mod}+e"       = "splith";

        "${mod}+a" = "layout stacking";
        "${mod}+s" = "layout tabbed";
        "${mod}+d" = "layout toggle split";
        "${mod}+f" = "fullscreen toggle";

        "${mod}+f+Shift" = "floating enable, mark --add center-float";
        "${mod}+g+Shift" = "floating disable";
        "${mod}+space"   = "focus mode_toggle";

        ## Move focus
        "${mod}+${cfg.config.left}"  = "focus left";
        "${mod}+${cfg.config.down}"  = "focus down";
        "${mod}+${cfg.config.up}"    = "focus up";
        "${mod}+${cfg.config.right}" = "focus right";

        ## Move focused
        "${mod}+Shift+${cfg.config.left}"  = "move left";
        "${mod}+Shift+${cfg.config.down}"  = "move down";
        "${mod}+Shift+${cfg.config.up}"    = "move up";
        "${mod}+Shift+${cfg.config.right}" = "move right";

        ## Resize window
        "${mod}+r" = "mode resize";

        ## Switch to workspace
        "${mod}+1"   = "workspace 1";
        "${mod}+2"   = "workspace 2";
        "${mod}+3"   = "workspace 3";
        "${mod}+8"   = "workspace 8";
        "${mod}+9"   = "workspace 9";
        "${mod}+Tab" = "workspace back_and_forth";

        ## Move focused container to workspace
        "${mod}+1+Shift" = "move container to workspace 1";
        "${mod}+2+Shift" = "move container to workspace 2";
        "${mod}+3+Shift" = "move container to workspace 3";
        "${mod}+8+Shift" = "move container to workspace 8";
        "${mod}+9+Shift" = "move container to workspace 9";

        # Workspaces
        "${mod}+Escape"       = "exec ${selectWs} | xargs swaymsg workspace";
        "${mod}+Escape+Shift" = "exec ${selectWs} | xargs swaymsg move container to workspace";
        "${mod}+F2"           = "exec ${selectWs} | xargs swaymsg rename workspace to";

        # Scratchpad
        "${mod}+q"              = "exec tmux detach-client -s flyway";
        "${mod}+q+Shift"        = "exec ${term} -a Scratchpad-flyway -- tmux new -As flyway";
        "${mod}+Return+Control" = ''
          exec OLD_ZDOTDIR=$ZDOTDIR ZDOTDIR=$ZDOTDIR_LAUNCHER ${term} \
            -W 120x10 -a launcher -e zsh
        '';

        ## Manage notifications
        "XF86Tools" = "exec ${actions."notifs:open".cmd}; mode notification-center";
      };

      input."*" = {
        tap = "enabled";
        xkb_layout = "us";
        xkb_variant = "intl";
        xkb_options = "caps:escape";
      };

      modes."resize" = {
        "${cfg.config.left}"  = "resize shrink width 10 px";
        "${cfg.config.down}"  = "resize grow height 10 px";
        "${cfg.config.up}"    = "resize shrink height 10 px";
        "${cfg.config.right}" = "resize grow width 10 px";
        "Escape"              = "mode default";
        "Return"              = "mode default";
      };

      modes."notification-center" = let
        exit = "exec ${actions."notifs:close".cmd}; mode default";
      in {
        "t"                   = "exec ${actions."notifs:toggle".cmd}";
        "Escape"              = exit;
        "Return"              = exit;
      };

      output."eDP-1".scale = "1";
      # Used for using the remarkable tablet as a second screen
      output."HEADLESS-1".mode = "1404x1872";

      floating.titlebar = false;
      floating.border = 1;
      floating.criteria = [
        { app_id = "launcher"; }
        { app_id = "^nm-connection-editor$"; }
        { title = "^About Mozilla Firefox$"; }
        { title = "^Complete Installation$"; }
        { title = "^Firefox — Sharing Indicator$"; }
        { title = "^Steam - News (.* of .*)$"; }
        { title = "^Steam - Update"; }
        { title = "^Steam - Self Updater$"; }
        { title = "^Steam Guard - Computer Authorization Required$"; }
      ];

      window.hideEdgeBorders = "smart";
      window.titlebar = false;
      window.border = 1;
      window.commands = [{
        criteria = { class = "Pinentry-gtk-2"; };
        command = "border normal";
      } {
        criteria = { con_mark = "center-float"; };
        command = "mark --toggle center-float";
      } {
        criteria = { app_id = "Scratchpad-flyway"; };
        command = "floating enable, mark --add center-float";
      } {
        criteria = { con_mark = "center-float"; floating = true; };
        command = ''
          exec swaymsg -t get_tree | \
            jq '.nodes|map(select(..|.focused?==true))\
                |first|.current_mode\
                |(([2*.width/3, 1080]|min|tostring) + " " + \
                  ([2*.height/3, 720]|min|tostring))' | \
            xargs swaymsg resize set
        '';
      }];

      startup = [
        { command = "systemctl --user set-environment DISPLAY=$DISPLAY"; }
        { command = "systemctl --user set-environment WAYLAND_DISPLAY=$WAYLAND_DISPLAY"; }
        { command = "systemctl --user set-environment SWAYSOCK=$SWAYSOCK"; }
        { command = "systemctl --user start graphical-session-pre.target"; }
        { command = "systemctl --user start graphical-session.target"; }
        { command = "systemctl --user start sway-session.target"; }
        { command = ''
            swayidle -w idlehint 300 \
              timeout 300   "${lockcmd} -f" \
              timeout 600   'swaymsg "output * dpms off"' \
              resume        'swaymsg "output * dpms on"' \
              before-sleep  "${lockcmd} -f" \
              lock          "${lockcmd} -f"
          '';
        }
      ];

      workspaceAutoBackAndForth = true;
    };

    systemdIntegration = false;  # Manually managed...

    # TODO: Integrate with the home-manager sway module...
    extraConfig = let
      getActiveCard = "pactl list sinks | grep -B 1 RUNNING | sed '1q;d' | sed 's/[^0-9]\\+//g'";
    in ''
      bindsym --locked ${mod}+XF86Display          output eDP-1 toggle

      bindsym --locked ${mod}+Delete               exec mpc toggle
      bindsym --locked ${mod}+End                  exec mpc prev
      bindsym --locked ${mod}+Insert               exec mpc next
      bindsym --locked XF86Display                 exec sm -i
      bindsym --locked XF86Display+Shift           exec sm

      bindsym --locked XF86MonBrightnessDown       exec brightnessctl s 5%-
      bindsym --locked XF86MonBrightnessDown+Shift exec brightnessctl s 1
      bindsym --locked XF86MonBrightnessUp         exec brightnessctl s 5%+
      bindsym --locked XF86MonBrightnessUp+Shift   exec brightnessctl s 100%

      bindsym --locked XF86Favorites exec systemd-inhibit --what=handle-lid-switch ${lockcmd}

      bindsym --locked XF86AudioMute        exec pactl set-sink-mute   "$(${getActiveCard})" toggle
      bindsym --locked XF86AudioLowerVolume exec pactl set-sink-volume "$(${getActiveCard})" -5%
      bindsym --locked XF86AudioRaiseVolume exec pactl set-sink-volume "$(${getActiveCard})" +5%
    '';
  };
}
