{ config, pkgs, lib, ... }: with lib; {
  options.roos.triglav.network.enable = mkEnableOption "Triglav-specific configuration";

  config = mkIf config.roos.triglav.network.enable {
    networking = {
      firewall = {
        enable = true;
        checkReversePath = false; # libvirt...
        allowPing = true;
        allowedTCPPorts = [
          22    # SSH
          2270  # foo
          5443  # bar
        ];
        allowedUDPPorts = [ 61573 ];
        trustedInterfaces = [ "Bifrost" "docker0" ];
        extraCommands = ''
          ip46tables -A nixos-fw -p gre -j nixos-fw-accept
        '';
      };

      hosts = {
        "127.0.0.1"       = ["Triglav" "triglav.roaming.orbstheorem.ch"];
        "5.2.74.181"      = ["Hellendaal" "hellendaal.orbstheorem.ch"];
      };

      networkmanager.enable = true;
    };
  };
}
