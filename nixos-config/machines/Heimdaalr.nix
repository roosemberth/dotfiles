{ config, pkgs, ... }:

{
  imports =
    [ ./hardware/KVM-Liteserver/NL-DRN-KVMSSDC-4.nix
    ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."vm.overcommit_memory" = "1";
  boot.kernelParams = [ "ip=5.2.67.130::5.2.67.1:255.255.255.0:heimdaalr.orbstheorem.ch:eth0" ];

  networking = {
    useDHCP = false;
    hostName = "heimdaalr.orbstheorem.ch"; # Define your hostname.
    domain = "orbstheorem.ch";
    enableIPv6 = true;
    interfaces = {
      "eth0" = {
        ipv4.addresses = [ { address = "5.2.67.130"; "prefixLength" = 24; } ];
        ipv6.addresses = [ { address = "2a04:52c0:101:25f::a796"; "prefixLength" = 64; } ];
      };
    };
    defaultGateway = { address = "5.2.67.1"; };
    defaultGateway6 = { address = "2a04:52c0:101::1"; };
    nameservers = [ "2a01:1b0:7999:446::1:4" "2a00:1ca8:18::1:104" "8.8.8.8" "8.8.4.4" ];
    useNetworkd = true;
    usePredictableInterfaceNames = false;
    extraHosts = ''
    '';
    firewall.enable = true;
    firewall.allowPing = true;
    firewall.allowedTCPPorts = [ 22 ];
  # firewall.allowedUDPPorts = [ ... ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  environment.systemPackages = with pkgs; [
    wget vim curl zsh git tmux htop atop iotop dropbear hdparm nox cacert
  ];

  programs.bash.enableCompletion = true;
  programs.mtr.enable = true;

  services = {
    openssh = {
      enable = true;
      gatewayPorts = "yes";
    # forwardX11 = true;
    };

  # snapper.configs = let
  #   extraConfig = ''
  #     ALLOW_GROUPS="wheel"
  #     TIMELINE_CREATE="yes"
  #     TIMELINE_CLEANUP="yes"
  #     EMPTY_PRE_POST_CLEANUP="yes"
  #   '';
  # in {
  #   "home" = {
  #     subvolume = "/home";
  #     inherit extraConfig;
  #   };
  # };
  };

  users.mutableUsers = false;
  users.users.roosemberth =
  { description = "Roosemberth Palacios";
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
    isNormalUser = true;
    shell = pkgs.zsh;
    uid = 19365;
    packages = with pkgs; [ # TODO: NixUp!
        ag dmidecode dnsutils file sbt openssl jq gitAndTools.git-annex lshw mr nethogs nfs-utils nix-index libnotify
        pciutils scala socat sshfs stress tig tinc unzip w3m whois youtube-dl gnupg pass irssi
    ];
  };

  system.nixos.stateVersion = "18.03";
  system.autoUpgrade.enable = true;
  system.copySystemConfiguration = true;

  security.sudo.enable = true;
}
