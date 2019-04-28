{ config, pkgs, lib, ... }: with lib; {
  options.roos.firewall.enable = mkEnableOption "Roos' firewall configuration";

  config = {
    extraHosts = ''
      5.2.74.181 Hellendaal hellendaal.orbstheorem.ch
      46.101.112.218 Heisenberg heisenberg.orbstheorem.ch
      95.183.51.23 Dellingr dellingr.orbstheorem.ch
    '';
    networkmanager.enable = true;
  } // mkIf config.roos.firewall.enable {
    networking.firewall = {
      enable = true;
      checkReversePath = false; # libvirt...
      allowPing = false;
      allowedTCPPorts = [ 22 ];
      allowedUDPPorts = [ 61573 ];
      trustedInterfaces = [ "Bifrost" "Feigenbaum" ];
      extraCommands = ''
        ip46tables -A nixos-fw -p gre -j nixos-fw-accept
      '';
    };
  };
}
