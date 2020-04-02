{ config, pkgs, lib, secrets, ... }: with lib;
let
  usersWithProfiles = attrValues config.roos.user-profiles;
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
        XDF_RUNTIME_DIR = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}";

        ZDOTDIR = "${homedir}/ws/1-Repositories/dotfiles/local/etc/zsh/default";
        GTK2_RC_FILES = "${userCfg.xdg.configHome}/gtk-2.0/gtkrc-2.0";
        GTK_RC_FILES = "${userCfg.xdg.configHome}/gtk-1.0/gtkrc";

        PASSWORD_STORE_DIR = "${XDG_LIB_HOME}/pass";
        GNUPGHOME = "${XDG_LIB_HOME}/gnupg";
        SSH_AUTH_SOCK = "${XDF_RUNTIME_DIR}/ssh-agent-$(id -un)-socket";
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
        epiphany
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
