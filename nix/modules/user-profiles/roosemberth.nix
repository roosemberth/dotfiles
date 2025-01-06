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
        moreutils
        openssl
        pv
        zsh-completions
      ]);
      programs.git = {
        enable = true;
        package = lib.mkDefault pkgs.gitMinimal;
        userEmail = "roosemberth@posteo.ch";
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
      programs.helix.enable = true;
      programs.helix.settings = {
        theme = "nightfox";
        editor.whitespace.render = "all";
        keys.normal = {
          "B" = "file_picker_in_current_buffer_directory";
        };
        keys.normal.space = {
          "f" = [
            ":new"
            ":insert-output ${pkgs.lf}/bin/lf -selection-path=/dev/stdout"
            "split_selection_on_newline"
            "goto_file"
            "goto_last_modification"
            "goto_last_modified_file"
            ":buffer-close!"
            ":redraw"
          ];
        };
      };
      programs.git.package = pkgs.gitFull;
      programs.gpg = {
        enable = true;
        homedir = "${userCfg.xdg.dataHome}/gnupg";
      };
    };

    roos.gConfigFn = userCfg: {
      home.packages = with pkgs; [
        bat
        brightnessctl
        epiphany
        evolution
        fortune
        fractal
        glances
        adwaita-icon-theme
        eog
        nautilus
        gnome-pomodoro
        gtk3  # gtk-launch
        links2
        mosh
        mumble
        ncmpcpp
        networkmanagerapplet
        pandoc
        screen-message
        slack
        socat
        tdesktop
        tree
        unzip
        wtype
        xkcdpass
        zip
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
          ninja-cookie
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
          extensions = baseExtensions;
        };
        profiles."moon" = {
          id = 1;
          settings = {};
          extensions = baseExtensions;
        };
        profiles."games" = {
          id = 2;
          settings = {};
          extensions = baseExtensions;
        };
        profiles."truss" = {
          id = 3;
          settings = {};
          extensions = with pkgs.nur.repos.rycee.firefox-addons;
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
