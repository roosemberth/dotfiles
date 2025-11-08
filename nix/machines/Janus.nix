{ config, pkgs, lib, ... }: let
  yubikey = { ... }: {
    environment.systemPackages = with pkgs; [ pcsc-tools yubikey-manager ];
    services.pcscd.enable = true;
  };
in {
  imports = [
    ./Janus-static.nix
    yubikey
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
  networking.firewall.allowedUDPPorts = [ 5355 ]; # LLMNR responses
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

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
  roos.evolution.enable = true;
  roos.media.enable = true;
  roos.steam.enable = true;
  roos.user-profiles.graphical = ["roosemberth"];

  programs.kdeconnect.enable = true;
  programs.seahorse.enable = true;
  services = {
    accounts-daemon.enable = true;
    ddccontrol.enable = true;
    fprintd.enable = false;  # Enabled by NixOS hardware (framework 13 7040).
    gnome.gnome-keyring.enable = true;
    gnome.gnome-online-accounts.enable = true;
    logind.powerKey = "ignore";
    resolved.enable = true;
    resolved.llmnr = "resolve";
    tailscale.enable = true;
  };
  system.stateVersion = "25.05";
  systemd.oomd.enableUserSlices = true;
  time.timeZone = "Europe/Zurich";
  users.users.roosemberth.home = "/var/home/roosemberth";

  virtualisation.podman.enable = true;
}
