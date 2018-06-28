{ config, pkgs, lib, ... }:

let
  secrets = import ../secrets.nix { inherit lib; };
in
{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ./Lappie-static.nix
  ];

  boot.cleanTmpDir = true;
  boot.kernelModules = [ "kvm-intel" ];

  environment.systemPackages = (with pkgs; [
    atop cacert curl git hdparm htop iotop libevdev tmux vim wget zsh
  ]);

  hardware = {
    bluetooth.enable = true;
    cpu.intel.updateMicrocode = true;
    opengl.driSupport32Bit = true;      # Steam...
  };

  networking = {
    hostName = "Lappie"; # Define your hostname.
    extraHosts = ''
      127.0.0.1       Lappie      lappie.intranet.orbstheorem.ch
      5.2.74.181      Hellendaal  hellendaal.orbstheorem.ch
      46.101.112.218  Heisenberg  heisenberg.orbstheorem.ch
      95.183.51.23    Dellingr    dellingr.orbstheorem.ch
    '';
    useNetworkd = true;
    interfaces.eno1.ipv4.addresses = [
      {address = "10.42.13.21"; prefixLength = 24; }
      {address = "169.254.13.21"; prefixLength = 16; }
    ];
    interfaces.eno1.useDHCP = true;
    firewall = {
      enable = true;
      checkReversePath = false; # libvirt...
      allowPing = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  nix = {
    buildCores = 8;
    trustedUsers = [ "roosemberth" ];
  };

  nixpkgs.config = {
    packageOverrides = pkgs: {
      unstable = import <nixos-unstable>;
    };
  };

  programs = {
    mosh.enable = true;
    mtr.enable = true;
    tmux.enable = true;
    tmux.newSession = true;
    vim.defaultEditor = true;
    zsh.enable = true;
    zsh.enableAutosuggestions = true;
    zsh.syntaxHighlighting.enable = true;
  };

  security.sudo.enable = true;

  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''
      HandlePowerKey="ignore"
    '';

    openssh = {
      enable = true;
      gatewayPorts = "yes";
    };

    udev.extraRules = ''
      # Cygnal Integrated Products, Inc. CP210x UART Bridge / myAVR mySmartUSB light
      ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="666", SYMLINK+="ttyUSB-odroid0"
      # Prolific Technology, Inc. PL2303 Serial Port
      ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", MODE="666", SYMLINK+="ttyUSB-odroid1"
     '';

    snapper.configs = let
      extraConfig = ''
        ALLOW_GROUPS="wheel"
        TIMELINE_CREATE="yes"
        TIMELINE_CLEANUP="yes"
        EMPTY_PRE_POST_CLEANUP="yes"
      '';
    in {
      "home" = {
        subvolume = "/home";
        inherit extraConfig;
      };
      "Storage" = {
        subvolume = "/Storage";
        inherit extraConfig;
      };
      "var" = {
        subvolume = "/var";
        extraConfig = ''
          ALLOW_GROUPS="wheel"
          NUMBER_LIMIT=3
          TIMELINE_CREATE="yes"
          TIMELINE_CLEANUP="yes"
          EMPTY_PRE_POST_CLEANUP="yes"
        '';
      };
    };
  };

  system = {
    stateVersion = "18.03";
    autoUpgrade.enable = true;
    copySystemConfiguration = true;
  };

  time.timeZone = "Europe/Zurich";

  users.mutableUsers = false;
  users.users.roosemberth =
  { uid = 1000;
    description = "Roosemberth Palacios";
    hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "docker"];
    openssh.authorizedKeys.keys = secrets.users.roosemberth.sshPubKey;
    packages = (with pkgs; [
      ag bc dfu-util dmidecode dnsutils dunst file gitAndTools.git-annex gnupg go-mtpfs jq libnfs libnotify
      lshw minicom mr msmtp neomutt nethogs nfs-utils nix-index openssl pass pciutils rfkill socat sshfs
      stress tig unzip usbutils w3m whois youtube-dl zip
      ]);
    shell = pkgs.zsh;
  };
  users.users.root.openssh.authorizedKeys.keys = secrets.users.roosemberth.sshPubKey;

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
