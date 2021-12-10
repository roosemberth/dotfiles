{ config, pkgs, lib, ... }:
let
  # Hack since secrets are not available to the machine top-level definition...
  networkDnsConfig =
    { secrets, ... }:
    {
      networking.nameservers = with secrets.network.zksDNS; v6 ++ v4;
      networking.search = with secrets.network.zksDNS; [ search ];
    };
in {
  imports = [
    ../modules
    ./Minerva-static.nix
    ./containers/databases.nix
    ./containers/named.nix
    ./containers/cabillaud-mysql.nix
    ./containers/greenzz.nix
    ./containers/greenzz-prod.nix
    ./containers/nextcloud.nix
    ./containers/matrix.nix
    ./containers/monitoring.nix
    ./containers/powerflow.nix
    networkDnsConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernelModules = [ "kvm-intel" ];

  environment.systemPackages = with pkgs; [
    gitAndTools.git-annex
    nvim-roos.essential
  ];

  hardware.cpu.intel.updateMicrocode = true;

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.package = pkgs.nixUnstable;
  nix.trustedUsers = [ "roosemberth" ];

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
  roos.nginx-fileshare.enable = true;
  roos.nginx-fileshare.directory = "/srv/shared";
  roos.user-profiles.reduced = ["roosemberth"];
  roos.wireguard.enable = true;
  roos.wireguard.gwServer = "Hellendaal";

  security.pam.enableSSHAgentAuth = true;
  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''HandlePowerKey="ignore"'';
    netdata.enable = true;
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    prometheus.exporters.node.enable = true;
    resolved.dnssec = "false";  # The named container DNS does not provide DNSSEC.
    resolved.llmnr = "false";
    tlp.enable = true;
    tlp.settings.CPU_SCALING_GOVERNOR_ON_AC = "performance";
    upower.enable = true;
  };

  system.stateVersion = "20.09";
  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

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
}
