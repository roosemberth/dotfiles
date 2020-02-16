{ config, pkgs, lib, ... }: 
with lib;
let
  secrets = import ../../secrets.nix { inherit lib; };
in {
  options.roos.user-profiles.roosemberth.enable = mkEnableOption "Roos' user profile";

  config = mkIf config.roos.user-profiles.roosemberth.enable {
    roos.mainUsers = [ "roosemberth" ];
    roos.xUserConfig = {
      systemd.user.services.take-a-break = {
        Unit = {
          Description = "Friendly reminder to take a break";
          After = [ "graphical-session-pre.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          Type = "oneshot";
          Environment = "GDK_SCALE=2";
          ExecStart = "${pkgs.writeScriptBin "take-a-break" ''
            #!${pkgs.stdenv.shell}

            ${pkgs.xlibs.xset}/bin/xset s activate
            (${pkgs.coreutils}/bin/seq 1 100 |
              (while read l; do echo $l; ${pkgs.coreutils}/bin/sleep 0.1; done) |
              ${pkgs.gnome3.zenity}/bin/zenity \
                --progress \
                --title 'break' \
                --text '10 second break!' \
                --no-cancel \
                --auto-close
            ) &> /dev/null

          ''}/bin/take-a-break";
        };
      };

      systemd.user.timers.take-a-break = {
        Unit.Description = "Reminder to take a break off the screen";
        Timer.OnCalendar="*-*-* *:00:00";
        Install.WantedBy = ["timers.target"];
      };

      services.random-background = {
        enable = true;
        imageDirectory = "%h/background-images";
        interval = "15m";
      };
    };

    users.users.roosemberth = {
      uid = 1000;
      description = "Roosemberth Palacios";
      hashedPassword = secrets.users.roosemberth.hashedPassword;
      isNormalUser = true;
      extraGroups = ["docker" "libvirtd" "networkmanager" "wheel" "wireshark"];
      packages = (with pkgs; [ # Web & comms
        firefox mosh openssh qutebrowser rtorrent w3m weechat x11_ssh_askpass
        gnome3.evolution
      ] ++ [ # Editors, documents, ...
        zathura vim_configurable neovim libreoffice pandoc pdftk
      ] ++ [ # Theme & fonts
        numix-solarized-gtk-theme lxappearance
        hack-font source-code-pro terminus_font_ttf powerline-fonts profont
      ] ++ (with pkgs.xorg;[ # xorg
        arandr argyllcms
        libXpm xbacklight xcape xclip xdotool xev xf86videointel xkbcomp xkill
        xprop xrestop xss-lock xtrlock-pam
      ]) ++ (with pkgs.aspellDicts;[ # dictionaries and language tools
        dico fr en-science en-computers es en de wordnet
      ]) ++ [ # Nix
        nix-bundle nix-index nix-prefetch-scripts nix-zsh-completions
        nix-diff
      ] ++ [ # Media
        beets mpc_cli mpd ncmpcpp pamix pavucontrol
      ] ++ [ # Debian
        aptly debian-devscripts debianutils debootstrap dpkg dtools
      ] ++ (with python3Packages;[ # python
        python3 ipython parse requests tox virtualenv mypy swig pylint flake8
      ]) ++ [ # Electronics & SDR
        kicad pulseview
        gnuradio-with-packages soapysdr-with-plugins
      ] ++ [ # Drawing, photo, video editing & imaging
        darktable inkscape krita scrot shutter xournal
        imagemagick slop screenkey ffmpeg asciinema
      ] ++ [ # Core & utils
        entr nmap screen socat stow tcpdump openssl ranger firejail
        ppp pptp proxychains virtmanager virtviewer nethogs cpulimit
        cpufrequtils lsof pciutils python3Packages.glances usbutils
        file docker moreutils tlp
      ] ++ [ # Triglav
        zip unzip jq khal tree pv fortune
        bluez powertop vlock
        taskwarrior timewarrior
        taffybar dunst upower
        alacritty rxvt_unicode-with-plugins
        gnupg pass-otp
        screen-message tdesktop vlc zsh-completions
      ] ++ [ # Dev
        ag arduino astyle binutils platformio
        dia ansible ansible-lint podman
        manpages
        cmake ctags elfutils gcc gdb gnumake gpgme libgpgerror radare2 valgrind
        idris lua luaPackages.luacheck
        silver-searcher sbt scala shellcheck openjdk
        mr tig gitAndTools.git-annex gitAndTools.git-crypt sqlite-interactive
      ] ++ [ # Haskell
        haskellPackages.fast-tags
      ]);
      shell = pkgs.zsh;
    };
  };
}
