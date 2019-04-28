{ config, pkgs, lib, ... }: with lib; {
  options.roos.user-profiles.roosemberth.enable = mkEnableOption "Roos' user profile";

  config = mkIf config.roos.user-profiles.roosemberth.enable {
    users.extraUsers.roosemberth = {
      uid = 1000;
      description = "Roosemberth Palacios";
      hashedPassword = "$6$QNnrghLeuED/C85S$vplnQU.q3cZmdso/FDfpwKVxmixhvPP9ots.2R6JfeVKQ2/FPPjHrdwddkuxvQfc8fKvl58JQPpjGd.LIzlmA0";
      isNormalUser = true;
      extraGroups = ["docker" "libvirtd" "networkmanager" "wheel" "wireshark"];
      packages = (with pkgs; [ # Legacy
        astyle baobab bc beets bind blender bluez coreutils cpufrequtils
        darktable dfu-util dmidecode dnsutils docker dolphin doxygen dunst
        enlightenment.terminology evtest exfat exif fbida fbterm feh ffmpeg file
        firefox firejail fontforge geteltorito gftp ghostscript gimp
        gitAndTools.git-annex gitAndTools.git-crypt glxinfo gnupg go-mtpfs
        gparted graphviz gucharmap hack-font i7z imagemagick imv intel-gpu-tools
        iw jq khal # libnfs
        libnotify libreoffice libtool libvirt libxml2 lm_sensors lshw lxappearance
        man-pages megatools mkpasswd moreutils mosh mpc_cli mpd mr
        mtpfs mypy ncftp ncmpc ncmpcpp neomutt neovim nethogs nfs-utils nitrogen
        nmap nss numix-solarized-gtk-theme oathToolkit offlineimap openconnect
        openjdk openssh openssl openvpn pamix pandoc pass pass-otp patchelf pavucontrol
        pbzip2 pciutils pdftk picocom pipenv postgresql powerline-fonts powertop
        ppp pptp profont proxychains psmisc pv qutebrowser radare2 ranger
        read-edid redshift remmina rfkill rtorrent rxvt_unicode-with-plugins s3cmd
        sakura scrot shutter smartmontools
        source-code-pro splint sshfs sshfs-fuse ssvnc stack stdman stress sway
        swig sysstat tasknc taskwarrior terminus_font_ttf
        texstudio timewarrior tlp tor transmission trayer tree unzip usbutils
        valgrind vim_configurable virtmanager virtviewer vlock w3m weechat whois
        wmname x11_ssh_askpass xlockmore xml2 xournal zathura zip zsh-completions
      ] ++ (with pkgs.xorg;[ # xorg
        libXpm xbacklight xcape xclip xdotool xev xf86videointel
        xkbcomp xkill xprop xrestop xss-lock xtrlock-pam
      ]) ++ (with pkgs.gnome3;[ # gnome
        baobab cheese eog evince evolution gedit gnome-contacts
        gnome-control-center networkmanagerapplet
        gnome-documents gnome-online-accounts gnome-maps gnome-settings-daemon
        gnome-system-monitor gnome-tweak-tool nautilus
      ]) ++ (with pkgs.aspellDicts;[ # dictionaries and language tools
        dico
        fr en-science en-computers es en de
      ]) ++ [ # Nix
        nix-bundle nix-index nix-prefetch-scripts nix-zsh-completions
      ] ++ [ # Debian
        aptly debian-devscripts debianutils debootstrap dpkg dtools
      ] ++ (with python3Packages; [  # python
        python3 ipython parse requests tox virtualenv
      ]) ++ [ # Electronics & SDR
        pulseview kicad
        gnuradio-with-packages soapysdr-with-plugins
      ] ++ [ # sysadmin
        python3Packages.glances lsof screen socat stow tcpdump
        libguestfs-with-appliance
      ] ++ [ # drawing
        inkscape krita
      ] ++ [ # Triglav
        arandr argyllcms adbfs-rootless enchant fortune msmtp mymopidy
        screen-message tdesktop
        rxvt_unicode-with-plugins taffybar upower vlc wordnet tigervnc
      ] ++ [ # Dev
        ag arduino binutils platformio
        cmake ctags elfutils gcc gdb gnumake gpgme idris libgpgerror
        lua luaPackages.luacheck
        silver-searcher sbt scala shellcheck
        tig
      ]) ++ (with pkgs.haskellPackages; [
        ghc cabal-install xmobar # hsqml leksah
      ]);
      shell = pkgs.zsh;
    };
  };
}
