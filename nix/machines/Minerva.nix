{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules
    ./Minerva-static.nix
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernelModules = [ "kvm-intel" ];
  hardware.cpu.intel.updateMicrocode = true;

  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.hostName = "Minerva";
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.enp0s31f6.tempAddress = "disabled";
  networking.nat.enable = true;
  networking.nat.internalInterfaces = ["ve-+"];
  networking.nat.externalInterface = "enp0s31f6";

  roos.dotfilesPath = ../..;
  roos.user-profiles.reduced = ["roosemberth"];
  roos.wireguard.enable = true;
  roos.wireguard.gwServer = "Hellendaal";

  security.pam.enableSSHAgentAuth = true;
  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''HandlePowerKey="ignore"'';
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    # resolved.enable = false;  # Use the named container DNS.
    tlp.enable = true;
    tlp.extraConfig = ''CPU_SCALING_GOVERNOR_ON_AC=performance'';
    upower.enable = true;
  };

  system.stateVersion = "20.09";
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
  # FIXME: Use systemd.watchdog.runtimeTime when merged
  systemd.extraConfig = "RuntimeWatchdogSec=10s";

  time.timeZone = "Europe/Zurich";

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

  virtualisation.libvirtd.enable = true;

  containers.named = {
    autoStart = true;
    config = { ... }: { imports = [../lib ./containers/named.nix]; };
    forwardPorts = [
      {hostPort = 53; protocol = "tcp";}
      {hostPort = 53; protocol = "udp";}
    ];
  };
}
