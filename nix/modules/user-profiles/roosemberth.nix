{ config, pkgs, lib, secrets, ... }: with lib;
let
  usersWithProfiles = attrValues config.roos.user-profiles;
  util = import ../util.nix { inherit config pkgs lib; };
in
{
  config = mkIf (any (p: elem "roosemberth" p) usersWithProfiles) {
    # Workaround for <https://github.com/rycee/home-manager/issues/1119>.
    boot.postBootCommands = ''
      mkdir -p /nix/var/nix/{profiles,gcroots}/per-user/roosemberth
      chown 1000 /nix/var/nix/{profiles,gcroots}/per-user/roosemberth
    '';

    users.users.roosemberth = {
      uid = 1000;
      description = "Roosemberth Palacios";
      hashedPassword = secrets.users.roosemberth.hashedPassword;
      isNormalUser = true;
      extraGroups = ["docker" "libvirtd" "networkmanager" "wheel" "input" "video"];
      shell = pkgs.zsh;
    };

    roos.rConfig = {
      home.packages = (with pkgs; [
        git
        gnupg
        moreutils
        nix-zsh-completions
        openssh
        openssl
        zsh-completions
      ]);
    };

    roos.rConfigFn = userCfg: let
      homedir = userCfg.home.homeDirectory;
    in {
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
          # Not backported yet
          # publicShare = "$HOME/Public";
          videos = "$HOME/Media/Videos";
        };
      };

      home.sessionVariables = rec {
        XDG_LIB_HOME = "$HOME/.local/lib";
        XDG_LOG_HOME = "$HOME/.local/var/log";

        ZDOTDIR = util.fetchDotfile "etc/zsh/default";
        ZDOTDIR_LAUNCHER = util.fetchDotfile "etc/zsh/launcher";
        GTK2_RC_FILES = "${userCfg.xdg.configHome}/gtk-2.0/gtkrc-2.0";
        GTK_RC_FILES = "${userCfg.xdg.configHome}/gtk-1.0/gtkrc";

        PASSWORD_STORE_DIR = "${userCfg.xdg.dataHome}/pass";
        GNUPGHOME = "${userCfg.xdg.dataHome}/gnupg";
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent-$(id -un)-socket";
      };

      systemd.user.startServices = true;

      xdg.configFile = mapAttrs (_: f: { source=util.fetchDotfile f.source; }) {
        "nvim/init.vim".source = "etc/nvim/init.vim";
      };

      home.file = {
        ".zshenv".text = "";  # empty file to silence zsh-newuser-install.
        # Systemd does not honot $XDG_CONFIG_HOME
        ".config/systemd".source =
          (pkgs.runCommandNoCCLocal "systemd-user-config-link" {} ''
            ln -s "${builtins.toString userCfg.xdg.configHome}/systemd" "$out"
          '');
      };
    };

    roos.sConfig = {
      home.packages = (with pkgs; [
        bluezFull
        git-crypt
        nix-index
        nmap
        ranger
        silver-searcher
        tig
        weechat
        wireguard
        xxd
      ]);
    };

    roos.gConfig = {
      home.packages = (with pkgs; [
        brightnessctl
        firefox
        (epiphany.override {webkitgtk = pkgs.webkitgtk.overrideAttrs (old: {
          cmakeFlags = assert lib.strings.versionOlder old.version "2.28.1";
            old.cmakeFlags ++ ["-DENABLE_BUBBLEWRAP_SANDBOX=OFF"];
        });})
        gnome3.gucharmap
        gtk3  # gtk-launch
        pinentry-gtk2
        tdesktop
        x11_ssh_askpass
      ]) ++ (with pkgs.bleeding-edge; [
        wdisplays wtype wlr-randr wl-clipboard # waybar
      ]);
    };

    security.sudo.extraConfig = ''
      %wheel      ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
      %wheel      ALL=(root) NOPASSWD: /run/current-system/sw/bin/lsof -nPi
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount -t proc none proc
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount /sys sys -o bind
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount /dev dev -o rbind
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount -t tmpfs none tmp
    '';

    assertions = [{
      assertion = config.security.sudo.enable;
      message = "User roosemberth requires sudo to be enabled.";
    }];
  };
}
