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

    roos.sConfig = {
      home.packages = (with pkgs; [
        bluezFull
        git-crypt
        git-annex
        git-annex-utils
        nix-index
        nmap
        ranger
        silver-searcher
        tig
        weechat
        xxd
        gomuks
      ]);
    };

    roos.gConfig = {
      home.packages = (with pkgs; [
        bat
        brightnessctl
        ungoogled-chromium
        firefox-wayland
        epiphany
        element-desktop
        fortune
        glances
        gnome3.adwaita-icon-theme
        gnome3.eog
        gnome3.nautilus
        gnome3.pomodoro
        gtk3  # gtk-launch
        khal
        libreoffice
        links2
        lsof
        mosh
        mumble
        networkmanagerapplet
        pandoc
        socat
        tdesktop
        tree
        unzip
        visidata
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
