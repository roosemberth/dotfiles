{ config, pkgs, lib, secrets, ... }: with lib;
let
  usersWithProfiles =
    flatten (with config.roos.user-profiles; [ graphical reduced simple ]);
in
{
  config = mkIf (elem "roosemberth" usersWithProfiles) {
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
      extraGroups = [
        "docker"
        "input"
        "libvirtd"
        "networkmanager"
        "tss"
        "video"
        "wheel"
        "wireshark"
      ];
      shell = pkgs.zsh;
    };

    roos.baseConfig.enable = true;

    roos.rConfigFn = userCfg: {
      home.packages = (with pkgs; [
        file
        moreutils
        nix-zsh-completions
        openssl
        pv
        zsh-completions
      ]);
      programs.git = {
        enable = true;
        package = lib.mkDefault pkgs.gitMinimal;
        userEmail = "roosemberth@posteo.ch";
        userName = "Roosembert Palacios";
        signing.key = "C2242BB7";
        signing.signByDefault = true;
        lfs.enable = true;
        extraConfig = {
          core.editor = "nvim";
          core.pager = "bat";
          commit.verbose = true;
          format.signOff = true;
          pull.ff = "only";
          tag.gpgSign = true;
          url."https://github.com/".insteadOf = [ "gh:" "github:" ];
          url."https://gitlab.com/".insteadOf = [ "gl:" "gitlab:" ];
          alias.c = "commit -s -v";
        };
      };
      programs.ssh = {
        enable = true;
        compression = true;
        extraConfig = "Include ${userCfg.xdg.dataHome}/ssh/config";
      };
    };

    roos.sConfigFn = userCfg: {
      home.packages = (with pkgs; [
        bluezFull
        git-crypt
        git-annex
        git-open
        git-annex-utils
        nix-index
        nmap
        ranger
        silver-searcher
        tig
        xxd
      ]);
      programs.git.package = pkgs.gitFull;
      programs.gpg = {
        enable = true;
        homedir = "${userCfg.xdg.dataHome}/gnupg";
      };
    };

    roos.gConfig = {
      home.packages = (with pkgs; [
        bat
        brightnessctl
        element-desktop
        epiphany
        firefox-wayland
        fortune
        glances
        gnome3.adwaita-icon-theme
        gnome3.eog
        gnome3.nautilus
        gnome3.pomodoro
        gtk3  # gtk-launch
        khal
        links2
        lsof
        mosh
        mumble
        ncmpcpp
        networkmanagerapplet
        pandoc
        screen-message
        socat
        tdesktop
        tree
        unzip
        visidata
        wtype
        xkcdpass
        zip
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
