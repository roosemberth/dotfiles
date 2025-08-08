{ config, pkgs, lib, users, ... }: with lib;
let
  usersWithProfiles =
    flatten (with config.roos.user-profiles; [ graphical reduced simple ]);
in
{
  config = mkIf (elem "roosemberth" usersWithProfiles) {
    # Workaround for <https://github.com/rycee/home-manager/issues/1119>.
    boot.postBootCommands = ''
      mkdir -p /nix/var/nix/{profiles,gcroots}/per-user/roosemberth
      chown 1000 /nix/var/nix/{profiles,gcroots}/per-user/roosemberth
    '';

    programs.zsh.enable = true;
    users.users.roosemberth = {
      uid = 1000;
      description = "Roosemberth Palacios";
      hashedPassword = users.roos.hashedPassword;
      isNormalUser = true;
      extraGroups = [
        "adbusers"
        "dialout"
        "docker"
        "input"
        "libvirtd"
        "networkmanager"
        "tss"
        "video"
        "wheel"
        "wireshark"
      ];
      openssh.authorizedKeys.keys = [ users.roos.ssh-public-key ];
      shell = pkgs.zsh;
    };

    roos.baseConfig.enable = true;

    roos.rConfigFn = userCfg: {
      home.packages = (with pkgs; [
        file
        fd
        moreutils
        openssl
        pv
        zsh-completions
      ]);
      programs.git = {
        enable = true;
        package = lib.mkDefault pkgs.gitMinimal;
        userName = "Roosembert Palacios";
        signing.key = "C2242BB7";
        signing.signByDefault = true;
        lfs.enable = true;
        extraConfig = {
          core.editor = "nvim";
          core.pager = "bat";
          commit.verbose = true;
          format.signOff = true;
          pull.ff = "only";
          tag.gpgSign = true;
          url."https://github.com/".insteadOf = [ "gh:" "github:" ];
          url."https://gitlab.com/".insteadOf = [ "gl:" "gitlab:" ];
          alias.c = "commit -s -v";
        };
      };
      programs.ssh = {
        enable = true;
        compression = true;
        userKnownHostsFile = "${userCfg.xdg.dataHome}/ssh/known_hosts";
        includes = [ "${userCfg.xdg.dataHome}/ssh/config" ];
      };
    };

    roos.sConfigFn = userCfg: {
      home.packages = (with pkgs; [
        bluez
        git-crypt
        git-annex
        git-open
        nix-index
        nmap
        ranger
        silver-searcher
        tig
        lf
        xxd
      ]);
      programs.git.package = pkgs.gitFull;
      programs.gpg = {
        enable = true;
        homedir = "${userCfg.xdg.dataHome}/gnupg";
      };
    };

    roos.gConfigFn = userCfg: {
      home.packages = with pkgs; [
        adwaita-icon-theme
        bat
        brightnessctl
        eog
        evolution
        fortune
        fractal
        glances
        gnome-pomodoro
        gtk3  # gtk-launch
        mumble
        nautilus
        screen-message
        signal-desktop
        socat
        sparrow
        tdesktop
        tree
        unzip
        wlr-randr
        wtype
        xkcdpass
        zip
        zulip
      ];

      programs.firefox = let
        baseExtensions = with pkgs.nur.repos.rycee.firefox-addons; [
          # Cookie quick manager
          # Dark background and light text?
          # fragments
          # UnloadTabs
          # Stop Auto Reload
          # Media Panel
          # BibItNow!
          # Enhancer for YouTube
          # Firefox Screenshots
          cookies-txt
          dark-mode-website-switcher
          darkreader
          df-youtube
          form-history-control
          localcdn
          multi-account-containers
          search-by-image
          sidebery
          temporary-containers
          terms-of-service-didnt-read
          translate-web-pages
          ublock-origin

          french-dictionary
        ];
      in {
        enable = true;
        profiles."default" = {
          id = 0;
          settings = {};
          isDefault = true;
          extensions.packages = baseExtensions;
        };
        profiles."moon" = {
          id = 1;
          settings = {};
          extensions.packages = baseExtensions;
        };
        profiles."games" = {
          id = 2;
          settings = {};
          extensions.packages = baseExtensions;
        };
        profiles."truss" = {
          id = 3;
          settings = {};
          extensions.packages = with pkgs.nur.repos.rycee.firefox-addons;
            [ metamask ublock-origin ];
        };
      };
    };

    assertions = [{
      assertion = config.security.sudo.enable;
      message = "User roosemberth requires sudo to be enabled.";
    }];
  };
}
