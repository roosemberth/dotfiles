{ config, pkgs, lib, ... }:
{
  imports = [
    ./Janus-static.nix
  ];

  boot.tmp.cleanOnBoot = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  roos.dotfilesPath = ../..;
  roos.user-profiles.reduced = ["roosemberth"];
  system.stateVersion = "25.05";
  users.users.roosemberth.home = "/var/home/roosemberth";
}
