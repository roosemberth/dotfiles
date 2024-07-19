{ config, lib, pkgs, ... }: with lib; let
in {
  options.programs.sway.roos-cfg.enable = mkEnableOption "Roos' config for sway";

  config.wayland.windowManager.sway = let
    cfg = config.wayland.windowManager.sway;
    mod = cfg.config.modifier;
    term = cfg.config.terminal;
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
        "${mod}+t+Control" = "exec ${actions."exec:term:attach-tmux".script}";
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
        "${mod}+v"            = "exec ${actions."exec:mpv:clipboard".script}";
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
        "${mod}+q+Shift"        = "exec ${actions."exec:term:open-scratchpad".script}";
        "${mod}+Return+Control" = "exec ${actions."exec:launcher:open".script}";

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
        { app_id = "aton.*"; }
        { app_id = "zenity"; }
        { app_id = ".*force_float.*"; }
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
        { command = "dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP"; }
        { command = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY"; }
        { command = "dbus-update-activation-environment --systemd SWAYSOCK"; }
        # Add only to systemd (not dbus), because required by askpass (ssh-agent).
        # I wish my system to be X11-free.
        { command = "systemctl --user set-environment DISPLAY=$DISPLAY"; }
        { command = "systemctl --user start sway-session.target"; }
      ];

      workspaceAutoBackAndForth = true;
    };

    systemd.enable = false;  # Manually managed...

    # TODO: Integrate with the home-manager sway module...
    extraConfig = ''
      bindsym --locked ${mod}+XF86Display          output eDP-1 toggle

      bindsym --locked ${mod}+Delete               exec ${actions."player:play-pause".cmd}
      bindsym --locked ${mod}+End                  exec ${actions."player:prev".cmd}
      bindsym --locked ${mod}+Insert               exec ${actions."player:next".cmd}
      bindsym --locked XF86Display                 exec sm -i
      bindsym --locked XF86Display+Shift           exec sm

      bindsym --locked XF86MonBrightnessDown       exec brightnessctl s 5%-
      bindsym --locked XF86MonBrightnessDown+Shift exec brightnessctl s 1
      bindsym --locked XF86MonBrightnessUp         exec brightnessctl s 5%+
      bindsym --locked XF86MonBrightnessUp+Shift   exec brightnessctl s 100%

      bindsym --locked XF86Favorites exec systemd-inhibit --what=handle-lid-switch swaylock

      bindsym --locked XF86AudioMute        exec ${actions."audio:vol-mute".script}
      bindsym --locked XF86AudioLowerVolume exec ${actions."audio:vol-down".script}
      bindsym --locked XF86AudioRaiseVolume exec ${actions."audio:vol-up".script}
    '';
  };
}
