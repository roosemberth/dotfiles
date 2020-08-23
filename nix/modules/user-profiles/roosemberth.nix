{ config, pkgs, lib, secrets, ... }: with lib;
let
  usersWithProfiles =
    flatten (with config.roos.user-profiles; [ graphical reduced simple ]);
  pinentry' = pkgs.writeShellScriptBin "pinentry" ''
    if [[ "$XDG_SESSION_TYPE" == "wayland" || "$XDG_SESSION_TYPE" = "x11" ]]; then
      exec ${pkgs.pinentry-gtk2}/bin/pinentry-gtk-2 "$@"
    else
      ${pkgs.ncurses}/bin/reset
      exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
    fi
  '';
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
        nix-index
        nmap
        ranger
        silver-searcher
        tig
        weechat
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
        gnome3.adwaita-icon-theme
        gtk3  # gtk-launch
        pinentry'
        tdesktop
        x11_ssh_askpass
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
