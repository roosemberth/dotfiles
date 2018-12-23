{ config, pkgs, ... }:

{
  imports = [
    ./Triglav-static.nix
    ../modules/isolated-external-networking.nix
    ./override-xmonad.nix
  ];

  environment.systemPackages = (with pkgs; [
    wget vim curl zsh git tmux htop atop iotop linuxPackages.bbswitch
    libevdev xorg.xf86inputevdev xclip xlibs.xmessage xmonad-with-packages
    firefox thunderbird rxvt_unicode-with-plugins
    hdparm
    nox cacert
    tinc_pre
  ]);

  hardware = {
    bluetooth.enable = true;
    cpu.intel.updateMicrocode = true;
    opengl.driSupport32Bit = true;      # Steam...
    pulseaudio.enable = true;
    pulseaudio.package = pkgs.pulseaudioFull;
    pulseaudio.support32Bit = true;     # Steam...
  };

  i18n.consoleFont = "sun12x22";

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
      allowedUDPPorts = [ 61573 ];
      trustedInterfaces = [ "Bifrost" "Feigenbaum" ];
      extraCommands = ''
        ip46tables -A nixos-fw -p gre -j nixos-fw-accept
      '';
    };
    wireguard.interfaces."Bifrost" = wireguardTriglav;
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

  powerManagement = {
    resumeCommands = ''
      ${config.systemd.package}/bin/systemctl restart bluetooth.service
    '';
    powerDownCommands = ''
      ${config.systemd.package}/bin/systemctl stop bluetooth.service
    '';
  };

  programs = {
    bash.enableCompletion = true;
    mtr.enable = true;
    wireshark.enable = true;
    wireshark.package = pkgs.wireshark;
  };

  security.sudo = {
    enable = true;
    extraConfig = ''%wheel  ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild'';
  };

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

    postgresql = {
      enable = true;
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
      # Honor 8
      ATTRS{idVendor}=="0925", ATTRS{idProduct}=="3881", MODE="666"
      # Suspend on low battery TODO: pre-death clock instead...
      SUBSYSTEM=="power_supply", ATTRS{capacity}=="10", ATTRS{status}=="Discharging", RUN+="${config.systemd.package}/bin/systemctl suspend"
     '';

    xserver = {
      enable = true;
      layout = "us";
      xkbVariant = "intl";

      # Enable touchpad support.
      libinput.enable = true;

      displayManager.sessionCommands = ''
        . $HOME/dotfiles/sh_environment
        . $XDG_CONFIG_HOME/sh/profile
        export XDG_CURRENT_DESKTOP=GNOME
        ${pkgs.nitrogen}/bin/nitrogen --set-auto background-images/venice.png
        ${pkgs.xcape}/bin/xcape -e 'Shift_L=Escape'
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap us intl -option caps:escape -option shift:both_capslock
        ${pkgs.xorg.xrdb}/bin/xrdb $XDG_CONFIG_HOME/X11/Xresources
        ${pkgs.xss-lock}/bin/xss-lock ${pkgs.xtrlock-pam}/bin/xtrlock-pam &!
      '';

      displayManager.slim.enable = true;
      displayManager.slim.defaultUser = "roosemberth";
      windowManager.xmonad.enable = true;
      windowManager.default = "xmonad";
      windowManager.xmonad.extraPackages =
        haskellPackages: with haskellPackages; [xmonad-contrib xmonad-extras];
      desktopManager.default = "gnome3";
      desktopManager.gnome3.enable = true;
      desktopManager.gnome3.debug = true;
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
    upower.enable = true;
  };

  system = {
    stateVersion = "18.03";
    autoUpgrade.enable = true;
    copySystemConfiguration = true;
  };

  time.timeZone = "Europe/Zurich";

  users.mutableUsers = false;
  users.extraUsers.roosemberth =
  { uid = 1000;
    description = "Roosemberth Palacios";
    hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
    isNormalUser = true;
    extraGroups = ["docker" "libvirtd" "networkmanager" "wheel" "wireshark"];
    packages = (with pkgs; [ # TODO: NixUp!
        ag argyllcms astyle bc bluez dfu-util dmidecode dnsutils dunst enlightenment.terminology file sbt mpd openssl jq
        gitAndTools.git-annex gitAndTools.git-crypt gnome3.eog gnome3.evince gnome3.nautilus go-mtpfs
        libnfs libpulseaudio lshw minicom mr msmtp ncmpcpp neomutt nethogs nfs-utils nitrogen nix-index gimp libnotify
        offlineimap openconnect openjdk pamix pavucontrol pciutils proxychains redshift rfkill rxvt_unicode-with-plugins
        scala scrot socat sshfs stress tig tinc tor unzip usbutils vpnc w3m whois xbindkeys xcape xtrlock-pam xorg.libXpm
        xorg.xbacklight xorg.xev xorg.xkbcomp xorg.xkill xournal zathura zip libnotify xclip youtube-dl gnupg pass irssi
      ]) ++ (with pkgs.haskellPackages; [
        xmobar # hsqml
      ]);
    shell = pkgs.zsh;
  };

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
