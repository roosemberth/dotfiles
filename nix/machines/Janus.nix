{ config, pkgs, lib, ... }:
{
  imports = [
    ./Janus-static.nix
  ];

  boot.tmp.cleanOnBoot = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware = {
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
    framework.laptop13.audioEnhancement.enable = true;
    graphics.enable = true;
  };

  networking.hostName = "janus";
  networking.networkmanager.enable = true;

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    settings.trusted-users = [ "roosemberth" ];
    registry.df.flake.outPath = "/var/home/roosemberth/ws/1-Repositories/dotfiles";
  };

  roos.agenda.enable = true;
  roos.cosmic.enable = true;
  roos.dev.enable = true;
  roos.dotfilesPath = ../..;
  roos.user-profiles.graphical = ["roosemberth"];

  programs.evolution.enable = true;
  programs.seahorse.enable = true;
  services = {
    accounts-daemon.enable = true;
    gnome.gnome-keyring.enable = true;
    gnome.gnome-online-accounts.enable = true;
    fprintd.enable = false;  # Enabled by NixOS hardware (framework 13 7040).
    tailscale.enable = true;
  };

  system.stateVersion = "25.05";
  users.users.roosemberth.home = "/var/home/roosemberth";

  virtualisation.podman.enable = true;
}
