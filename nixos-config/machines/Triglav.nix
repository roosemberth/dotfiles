{ config, pkgs, lib, ... }:

let
  bleedingEdge =
    let try = builtins.tryEval <nixpkgs-unstable>;
    in if try.success then builtins.trace "Using nixos-unstable for bleeding edge" (import try.value {}) else pkgs;
  wireguardTriglav = import ./systech-wireguard.nix {inherit lib config;};
in
{
  imports = [
    ./Triglav-static.nix
  ];

  environment.systemPackages = (with pkgs; [
    wget vim curl zsh git tmux htop atop iotop linuxPackages.bbswitch
    nfs-utils ethtool hdparm ntopng netdata
    linuxPackages.tp_smapi
    libevdev xorg.xf86inputevdev xclip xlibs.xmessage
    firefox thunderbird rxvt_unicode-with-plugins
    nox cacert
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

  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        gitAndTools = pkgs.gitAndTools // ({
          git-annex = with pkgs; (haskell.lib.overrideSrc gitAndTools.git-annex
            (let version = "6.20180901-1"; in {
              inherit version;
              src = fetchgit {
                name = "git-annex-${version}";
                url = "git://git-annex.branchable.com/";
                rev = "522c5cce58c9f19d78a868ab3b1e3399ae09a1d5";
                sha256 = "0hmqphgnrbhhi11x34j8244h3nnnsnal212iwjshp3wqf957dl1g";
              };
          }));
        });
        mymopidy = with pkgs; buildEnv {
          name = "mopidy-with-extensions";
          paths = lib.closePropagation (with pkgs; [mopidy-spotify mopidy-iris]);
          pathsToLink = [ "/${python.sitePackages}" ];
          buildInputs = [ makeWrapper ];
          postBuild = ''
            makeWrapper ${mopidy}/bin/mopidy $out/bin/mopidy \
            --prefix PYTHONPATH : $out/${python.sitePackages}
          '';
        };
      };
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
    packages = (with pkgs; [ # Legacy
      astyle baobab bc beets bind blender bluez coreutils cpufrequtils
      darktable dfu-util dico dmidecode dnsutils docker dolphin doxygen dunst
      enlightenment.terminology evtest exfat exif fbida fbterm feh ffmpeg file
      firefox firejail fontforge fortune geteltorito gftp ghostscript gimp
      gitAndTools.git-annex gitAndTools.git-crypt glxinfo gnupg go-mtpfs
      gparted graphviz gucharmap hack-font i3 i7z imagemagick imv intel-gpu-tools
      iw jq khal kicad # libnfs
      libnotify libreoffice libtool libvirt libxml2 lm_sensors lshw lxappearance
      man-pages megatools minicom mkpasswd moreutils mosh mpc_cli mpd mr
      mtpfs mypy ncftp ncmpc ncmpcpp neomutt neovim nethogs nfs-utils nitrogen
      nmap nss numix-solarized-gtk-theme oathToolkit offlineimap openconnect
      openjdk openssh openssl openvpn pamix pandoc pass patchelf pavucontrol
      pbzip2 pciutils pdftk picocom pipenv postgresql powerline-fonts powertop
      ppp pptp profont proxychains psmisc pv python3 qutebrowser radare2 ranger
      read-edid redshift remmina rfkill rtorrent rxvt_unicode-with-plugins s3cmd
      sakura screen-message scrot shutter silver-searcher smartmontools socat
      source-code-pro splint sshfs sshfs-fuse ssvnc stack stdman stress sway
      swig sysstat tasknc taskwarrior tcpdump terminus_font_ttf
      texstudio timewarrior tlp tor transmission trayer tree unzip usbutils
      valgrind vim_configurable virtmanager virtviewer vlock w3m weechat whois
      wmname x11_ssh_askpass xbindkeys xcape xclip xdotool
      xlockmore xml2 xournal xrestop xss-lock xtrlock-pam youtube-dl
      zathura zip zsh-completions
    ] ++ (with pkgs.xorg;[ # xorg
      libXpm xbacklight xev xf86videointel xkbcomp xkill xprop
    ]) ++ (with pkgs.gnome3;[ # gnome
      baobab california cheese eog evince evolution gedit gnome-contacts
      gnome-control-center networkmanagerapplet
      gnome-documents gnome-online-accounts gnome-maps gnome-settings-daemon
      gnome-system-monitor gnome-tweak-tool nautilus
    ]) ++ (with pkgs.aspellDicts;[ # dictionaries
      fr en-science en-computers es en de
    ]) ++ [ # Nix
      nix-bundle nix-index nix-prefetch-scripts nix-zsh-completions
  # ] ++ [ # Debian
  #   apt aptly debian-devscripts debianutils debootstrap dpkg
    ] ++ (with python3Packages; [  # python
      ipython parse requests tox virtualenv notebook ipykernel
    ]) ++ [ # Electronics
      pulseview
    ] ++ [ # sysadmin
      lsof
    ] ++ [ # drawing
      inkscape krita
    ] ++ [ # Triglav
      arandr argyllcms adbfs-rootless enchant msmtp mymopidy tdesktop
      rxvt_unicode-with-plugins taffybar upower vlc wordnet
    ] ++ [ # Dev
      ag arduino binutils
      cmake ctags elfutils gcc gdb gnumake gpgme idris libgpgerror
      lua luaPackages.luacheck
      sbt scala shellcheck
      tig
    ]) ++ (with pkgs.haskellPackages; [
      xmobar # hsqml leksah
    ]) ++ (with bleedingEdge; [
    # pkgs.soapysdr-with-plugins
      mpv youtube-dl
    ]);
    shell = pkgs.zsh;
  };

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
