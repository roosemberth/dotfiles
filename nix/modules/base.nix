{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
  vim' = pkgs.writeShellScriptBin "vim" ''exec ${pkgs.neovim}/bin/nvim "$@"'';
in
{
  options.roos.baseConfig.enable = mkEnableOption "Arbitrary base configuration.";

  config = mkIf config.roos.baseConfig.enable {
    roos.rConfigFn = userCfg: let
      homedir = userCfg.home.homeDirectory;
    in {
      home.file = {
        ".zshenv".text = "";  # empty file to silence zsh-newuser-install.
        # Systemd does not honot $XDG_CONFIG_HOME
        ".config/systemd".source =
          (pkgs.runCommandNoCCLocal "systemd-user-config-link" {} ''
            ln -s "${builtins.toString userCfg.xdg.configHome}/systemd" "$out"
          '');
      };

      home.packages = (with pkgs; [
        git
        moreutils
        nix-zsh-completions
        openssh
        openssl
        tmux
        zsh-completions
      ]);

      home.sessionVariables = rec {
        ZDOTDIR = util.fetchDotfile "etc/zsh/default";
        ZDOTDIR_LAUNCHER = util.fetchDotfile "etc/zsh/launcher";
        GTK2_RC_FILES = "${userCfg.xdg.configHome}/gtk-2.0/gtkrc-2.0";
        GTK_RC_FILES = "${userCfg.xdg.configHome}/gtk-1.0/gtkrc";
        # Preserve if existing (e.g. agent forwarding).
        SSH_AUTH_SOCK = "\${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent-$(id -un)-socket}";
      };

      systemd.user.startServices = true;

      xdg = {
        enable = true;
        cacheHome = "${homedir}/.local/var/cache";
        configHome = "${homedir}/.local/etc";
        dataHome = "${homedir}/.local/var/lib";
        userDirs = {
          enable = true;
          download = "/tmp";
          music = "$HOME/Media/Music";
          pictures = "$HOME/Media/Pictures";
          publicShare = "$HOME/Public";
          videos = "$HOME/Media/Videos";
        };
      };

      xdg.configFile."nvim/init.vim".source = util.fetchDotfile "etc/nvim/init.vim";
    };

    roos.sConfig = {
      home.packages = with pkgs; [
        posix_man_pages man-pages glances
      ];
    };

    environment.systemPackages = with pkgs; [
      cacert curl hdparm htop iotop neovim vim' wget exfat nfsUtils
    ];

    programs.bash.enableCompletion = true;
    programs.mtr.enable = true;
  };
}