{ config, pkgs, lib, ... }: let
  bindConfig = { secrets, ... }: {
    networking.firewall.allowedUDPPorts = [53];
    services.bind = {
      enable = true;
      zones = [{
        name = "orbstheorem.ch";
        master = true;
        file = secrets.network.bind-zones."orbstheorem.ch";
      }];
    };
  };
in {
  imports = [
    ../modules
    ./Heimdaalr-static.nix
    bindConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions

  networking.hostName = "Heimdaalr";
  networking.useNetworkd = true;
  networking.useDHCP = false;

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.package = pkgs.nixUnstable;
  nix.trustedUsers = [ "roosemberth" ];

  roos.dotfilesPath = ../..;
  roos.user-profiles.reduced = ["roosemberth"];

  security.pam.enableSSHAgentAuth = true;
  services = {
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    resolved.llmnr = "false";
  };
  system.stateVersion = "21.11";

  users = {
    mutableUsers = false;
    motd = with config; ''
      Welcome to ${networking.hostName}

      - This machine is managed by NixOS
      - All changes are futile

      OS:      NixOS ${system.nixos.release} (${system.nixos.codeName})
      Version: ${system.nixos.version}
      Kernel:  ${boot.kernelPackages.kernel.version}
    '';
  };
}
