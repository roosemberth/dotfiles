{ config, pkgs, ... }:

{
  imports =
    [ ./hardware/KVM-Liteserver/NL-DRN-KVMSSDC-4.nix
    ];

  boot.cleanTmpDir = true;

  networking = {
    hostName = "Heimdaalr.orbstheorem.ch"; # Define your hostname.
    extraHosts = ''
    '';
    firewall.enable = true;
    firewall.allowPing = true;
    firewall.allowedTCPPorts = [ 22 ];
  # firewall.allowedUDPPorts = [ ... ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    wget vim curl zsh git tmux htop atop iotop
    hdparm nox cacert tinc_pre
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.bash.enableCompletion = true;
  programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  services = {
    openssh = {
      enable = true;
      gatewayPorts = "yes";
    # forwardX11 = true;
    };

  # xserver.enable = false;

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
  users.extraUsers.roosemberth =
  { uid = 1000;
    description = "Roosemberth Palacios";
    hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [ # TODO: NixUp!
        ag dmidecode dnsutils file sbt openssl jq gitAndTools.git-annex lshw mr nethogs nfs-utils nix-index libnotify
        pciutils scala socat sshfs stress tig tinc unzip w3m whois youtube-dl gnupg pass irssi
    ];
    shell = pkgs.zsh;
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
  };

  system.stateVersion = "17.09";

  security.sudo.enable = true;
}
