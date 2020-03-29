{ config, pkgs, lib, secrets, ... }: with lib;
let
  usersWithProfiles = attrValues config.roos.user-profiles;
in
{
  config = mkIf (any (p: elem "roosemberth" p) usersWithProfiles) {
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
        gnupg
        nix-zsh-completions
        openssh
        openssl
        zsh-completions
      ]);
    };

    roos.sConfig = {
      home.packages = (with pkgs; [
        bluezFull
        nmap
      ]);
    };

    roos.gConfig = {
      home.packages = (with pkgs; [
        pinentry-gtk2
        x11_ssh_askpass
        gnome3.gucharmap
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
