{ config, pkgs, lib, ... }:
{
  imports = [
    ./Janus-static.nix
  ];

  boot.tmp.cleanOnBoot = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.gnome.excludePackages = with pkgs; [
    orca gnome-backgrounds gnome-color-manager gnome-shell-extensions
    gnome-tour gnome-user-docs orca gnome-menus
  ];

  hardware = {
    bluetooth.enable = true;
    enableRedistributableFirmware = true;
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
  };

  roos.agenda.enable = true;
  roos.cosmic.enable = true;
  roos.dotfilesPath = ../..;
  roos.user-profiles.graphical = ["roosemberth"];

  services = {
    tailscale.enable = true;
    # Despite being in the xserver namespace, this does not enable any of X11.
    xserver.desktopManager.gnome.enable = true;
    xserver.displayManager.gdm.enable = true;
  };

  system.stateVersion = "25.05";
  users.users.roosemberth.home = "/var/home/roosemberth";

  virtualisation.podman.enable = true;
}
