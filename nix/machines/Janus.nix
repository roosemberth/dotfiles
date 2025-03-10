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
  system.stateVersion = "25.05";
  users.users.roosemberth.home = "/var/home/roosemberth";

  virtualisation.podman.enable = true;
}
