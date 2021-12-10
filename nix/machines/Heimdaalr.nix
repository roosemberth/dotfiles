{ config, pkgs, lib, ... }: let
  bindConfig = { secrets, ... }: let
    zone."orbstheorem.ch" = "/run/bind/orbstheorem.ch.zone";
  in {
    networking.firewall.allowedUDPPorts = [53];
    services.bind = {
      enable = true;
      extraConfig = ''
        include "/keyring/dns/dns-orbstheorem.ch.keys.conf";
      '';
      zones = [{
        name = "orbstheorem.ch";
        master = true;
        # Writeable so it can be updated during acme provisioning via rfc2136.
        file = zone."orbstheorem.ch";
        extraConfig = "allow-update { key rfc2136key.orbstheorem.ch.; };";
      }];
    };
    systemd.services.bind.preStart = let
      srcfile = secrets.network.bind-zones."orbstheorem.ch";
      cfgfile = pkgs.writeText "Replace orbstheorem.ch zone file.tmpfiles" ''
        d /run/bind 0700 named root 0
        C ${zone."orbstheorem.ch"} 0400 named root - ${srcfile}
      '';
    in ''
      ${pkgs.systemd}/bin/systemd-tmpfiles --create --remove "${cfgfile}"
    '';
    systemd.tmpfiles.rules = [
      "f /keyring/dns/dns-orbstheorem.ch.keys.conf 0400 named root -"
    ];
  };
  acmeConfig = { secrets, ... }: {
    security.acme.acceptTerms = true;
    security.acme.email = secrets.network.acme.email;
    security.acme.certs."orbstheorem.ch" = {
      domain = "orbstheorem.ch";
      dnsProvider = "rfc2136";
      credentialsFile = "/keyring/acme/orbstheorem.ch.secret";
      dnsPropagationCheck = false;
    };
    systemd.tmpfiles.rules = [
      "f /keyring/acme/orbstheorem.ch.secret 0400 acme root -"
    ];
  };
in {
  imports = [
    ../modules
    ./Heimdaalr-static.nix
    acmeConfig
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
