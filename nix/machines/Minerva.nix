{ config, pkgs, lib, ... }:
let
  networkConfig = { secrets, ... }: let
    hostBridgeV4Addrs = [{ address = "10.231.136.1"; prefixLength = 24; }];
  in {
    networking = {
      # Ask the named container to resolve DNS for us.
      nameservers = with secrets.network.zksDNS; v6 ++ v4;
      search = with secrets.network.zksDNS; [ search ];
    };
    services.resolved = {
      dnssec = "false";  # Our upstream DNS server does not provide DNSSEC.
      llmnr = "false";
      extraConfig = ''
        # Allow queries from containers.
        ${lib.concatMapStringsSep "\n"
            (v: "DNSStubListenerExtra=${v.address}") hostBridgeV4Addrs}
      '';
    };
    roos.container-host = {
      enable = true;
      iface.ipv4.addresses = hostBridgeV4Addrs;
      # Cache DNS for containers.
      # This implies containers can resolve protected networks.
      nameservers = map (v: v.address) hostBridgeV4Addrs;
    };
    networking.firewall.extraCommands = ''
      iptables -w -t nat -D POSTROUTING -j minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -F minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -X minerva-nat-post 2>/dev/null || true
      iptables -w -t nat -N minerva-nat-post
      # Assent connections from the monitoring into Yggdrasil.
      iptables -w -t nat -I minerva-nat-post \
        -s 10.231.136.6 -d 10.13.0.0/16 -j MASQUERADE
      # Hairpin so inter-container responses match expected source address.
      iptables -w -t nat -I minerva-nat-post \
        -s 10.231.136.0/24 -d 10.231.136.0/24 -j MASQUERADE
      iptables -w -t nat -I POSTROUTING -j minerva-nat-post
    '';
  };
in {
  imports = [
    ../modules
    ./Minerva-static.nix
    ./containers/databases.nix
    ./containers/home-automation.nix
    ./containers/named.nix
    ./containers/nextcloud.nix
    ./containers/matrix.nix
    ./containers/monitoring.nix
    ./containers/powerflow.nix
    networkConfig
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
  roos.wireguard.gwServer = "Heimdaalr";

  security.pam.enableSSHAgentAuth = true;
  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''HandlePowerKey="ignore"'';
    netdata.enable = true;
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    prometheus.exporters.node.enable = true;
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
