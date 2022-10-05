{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in
{
  options.roos.baseConfig.enable = mkEnableOption "Arbitrary base configuration.";

  config = mkIf config.roos.baseConfig.enable {
    roos.rConfigFn = userCfg: let
      homedir = userCfg.home.homeDirectory;
    in {
      home.file = {
        ".tmux.conf".source =
          "${util.renderDotfile "etc/tmux" {}}/main.tmux.conf";
        ".zshenv".text = "";  # empty file to silence zsh-newuser-install.
        # Systemd does not honot $XDG_CONFIG_HOME
        ".config/systemd".source =
          (pkgs.runCommandLocal "systemd-user-config-link" {} ''
            ln -s "${builtins.toString userCfg.xdg.configHome}/systemd" "$out"
          '');
      };

      home.packages = (with pkgs; [
        moreutils
        nix-zsh-completions
        openssl
        tmux
        zsh-completions
      ]);

      home.sessionPath = [ "\$HOME/.local/bin" ];
      home.sessionVariables = rec {
        ZDOTDIR = util.fetchDotfile "etc/zsh/default";
        ZDOTDIR_LAUNCHER = util.fetchDotfile "etc/zsh/launcher";
        GTK2_RC_FILES = "${userCfg.xdg.configHome}/gtk-2.0/gtkrc-2.0";
        GTK_RC_FILES = "${userCfg.xdg.configHome}/gtk-1.0/gtkrc";
        # Preserve if existing (e.g. agent forwarding).
        SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent-$(id -un)-socket}";
        EDITOR = "nvim";
      };

      systemd.user.startServices = true;

      xdg = {
        enable = true;
        cacheHome = "${homedir}/.local/var/cache";
        configHome = "${homedir}/.local/etc";
        dataHome = "${homedir}/.local/var/lib";
      };
    };

    roos.sConfig = {
      home.packages = with pkgs; [
        man-pages-posix man-pages
        python3 python3Packages.ipython glances
      ];
      programs.vim-roos.enable = true;

      xdg = {
        mime.enable = true;
        userDirs = {
          enable = true;
          download = "/tmp";
          music = "$HOME/Media/Music";
          pictures = "$HOME/Media/Pictures";
          publicShare = "$HOME/Public";
          videos = "$HOME/Media/Videos";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      cacert curl hdparm htop atop iotop powertop btop wget exfat nfs-utils
      lsof fzf comma
    ];

    security.sudo.extraRules = let
      nopasswdcmds = [
        "atop"
        "btop"
        "htop"
        "lsof -nPi"
        "nixos-rebuild"
        "powertop"
      ];
    in [
      {
        groups = [ "wheel" ];
        commands = map (cmd: {
          command = "/run/current-system/sw/bin/${cmd}";
          options = [ "NOPASSWD" ];
        }) nopasswdcmds;
      }
    ];

    programs.bash.enableCompletion = true;
    programs.mtr.enable = true;
  };
}
