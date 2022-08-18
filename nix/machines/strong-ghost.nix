{ config, pkgs, lib, modulesPath, ... }: let
in {
  imports = [
    ../modules
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  ec2.hvm = true;

  environment.systemPackages = [ pkgs.nvim-roos-essential ];
  networking.hostName = "strong-ghost";

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.package = pkgs.nixUnstable;
  nix.trustedUsers = [ "roosemberth" ];

  roos.dotfilesPath = ../..;
  roos.user-profiles.reduced = ["roosemberth"];

  security.pam.enableSSHAgentAuth = true;
  services = {
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    openssh.extraConfig = "PermitTunnel yes";
    netdata.enable = true;
  };
  system.stateVersion = "22.05";

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
