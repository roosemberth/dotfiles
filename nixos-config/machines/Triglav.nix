{ config, pkgs, ... }:

{
  imports =
    [ ./hardware/Lenovo-P50.nix
      ../modules/isolated-external-networking.nix
      ./override-xmonad.nix
    ];

  boot.cleanTmpDir = true;
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "nouveau.runpm=0" /* "nopti" */];

  networking = {
    hostName = "Triglav"; # Define your hostname.
    extraHosts = ''
      127.0.0.1 Triglav triglav.roaming.orbstheorem.ch
      5.2.74.181 Hellendaal hellendaal.orbstheorem.ch
      46.101.112.218 Heisenberg heisenberg.orbstheorem.ch
      95.183.51.23 Dellingr dellingr.orbstheorem.ch
    '';
    networkmanager.enable = true;
  # isolateExternalNetworking.enable = true;
    isolateExternalNetworking.whitelist = [ "wlp4s0" ];
    firewall = {
      enable = true;
      checkReversePath = false; # libvirt...
      allowPing = false;
      allowedTCPPorts = [ 22 ];
  #   allowedUDPPorts = [ ... ];
      trustedInterfaces = [ "Feigenbaum" ];
      extraCommands = ''
        ip46tables -A nixos-fw -p gre -j nixos-fw-accept
      '';
    };
  };

  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };

  # Set your time zone.
  time.timeZone = "Europe/Zurich";

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    wget vim curl zsh git tmux htop atop iotop linuxPackages.bbswitch
    libevdev xorg.xf86inputevdev xclip xlibs.xmessage xmonad-with-packages
    firefox thunderbird rxvt_unicode-with-plugins
    hdparm
    nox cacert
    tinc_pre
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.bash.enableCompletion = true;
  programs.mtr.enable = true;
  # programs.gnupg.agent = { enable = true; enableSSHSupport = true; };

  services = {
    logind.lidSwitch = "ignore";
    logind.extraConfig = ''
      HandlePowerKey="ignore"
    '';

    openssh = {
      enable = true;
      gatewayPorts = "no";
      forwardX11 = true;
    };

    udev.extraRules = ''
      ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="6108", MODE="666", SYMLINK+="LimeSDR"
      ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="666", SYMLINK+="EPFL-Gecko4Education"
      ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6101", MODE="666", SYMLINK+="EPFL-Gecko4Education"
      ATTRS{idVendor}=="04b4", ATTRS{idProduct}=="00f3", MODE="666", SYMLINK+="FX3"
      #Bus 003 Device 055: ID 10c4:ea60 Cygnal Integrated Products, Inc. CP210x UART Bridge / myAVR mySmartUSB light
      ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="666", SYMLINK+="ttyUSB-odroid0"
      #Bus 001 Device 005: ID 067b:2303 Prolific Technology, Inc. PL2303 Serial Port
      ATTRS{idVendor}=="067b", ATTRS{idProduct}=="2303", MODE="666", SYMLINK+="ttyUSB-odroid1"
      # Suspend on low battery TODO: pre-death clock instead...
      SUBSYSTEM=="power_supply", ATTRS{capacity}=="10", ATTRS{status}=="Discharging", RUN+="${config.systemd.package}/bin/systemctl suspend"
     '';

    postgresql = {
      enable = true;
      package = pkgs.postgresql100;
    };

    xserver = {
      # Enable the X11 windowing system.
      enable = true;
      enableTCP = true;
      layout = "us";
      xkbVariant = "intl";

      # Enable touchpad support.
      libinput.enable = true;

      displayManager.slim.enable = true;
      displayManager.slim.defaultUser = "roosemberth";
    };

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
      "DevelHub" = {
        subvolume = "/Storage/DevelHub";
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

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
# nixup.enable = true;
  nix = {
    package = pkgs.nixUnstable;
    trustedUsers = [ "roosemberth" ];
  };

  users.mutableUsers = false;
  users.extraUsers.roosemberth =
  { uid = 1000;
    description = "Roosemberth Palacios";
    hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker"];
    packages = with pkgs; [ # TODO: NixUp!
        ag argyllcms astyle bc bluez dfu-util dmidecode dnsutils dunst enlightenment.terminology file sbt mpd openssl jq
        gitAndTools.git-annex gnome3.eog gnome3.evince gnome3.nautilus go-mtpfs haskellPackages.xmobar i3 i3lock
        libnfs libpulseaudio lshw minicom mr msmtp ncmpcpp neomutt nethogs nfs-utils nitrogen nix-index gimp libnotify
        offlineimap openconnect openjdk pamix pavucontrol pciutils proxychains redshift rfkill rxvt_unicode-with-plugins
        scala scrot socat sshfs stress tig tinc tor unzip usbutils vpnc w3m whois xbindkeys xcape xtrlock-pam xorg.libXpm
        xorg.xbacklight xorg.xev xorg.xkbcomp xorg.xkill xournal zathura zip libnotify xclip youtube-dl gnupg pass irssi
    ];
    shell = pkgs.zsh;
  };

  hardware = {
    pulseaudio.enable = true;
    pulseaudio.package = pkgs.pulseaudioFull;
    pulseaudio.support32Bit = true;     # Steam...
    opengl.driSupport32Bit = true;      # Steam...
    bluetooth.enable = true;
    cpu.intel.updateMicrocode = true;
  # bumblebee.enable = true;
  # bumblebee.driver = "nvidia";
  # bumblebee.connectDisplay = false;   # Else bumblebee doesn't work...
  };

  system = {
    # This value determines the NixOS release with which your system is to be
    # compatible, in order to avoid breaking some software such as database
    # servers. You should change this only after NixOS release notes say you
    # should.
    stateVersion = "18.03"; # Did you read the comment?
    autoUpgrade.enable = true;
    copySystemConfiguration = true;
  };

  security.sudo = {
    enable = true;
    #extraConfig = ''
    #    %wheel  ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild switch
    #'';
  };

  nixpkgs.config = {
  # allowUnfree = true;
    # Create an alias for the unstable channel
    packageOverrides = pkgs: {
      unstable = import <nixos-unstable> {
        # pass the nixpkgs config to the unstable alias
        # to ensure `allowUnfree = true;` is propagated:
        config = config.nixpkgs.config;
      };
    };
  };
}
