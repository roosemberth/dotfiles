{ config, pkgs, lib, ... }:

let
  bleedingEdge =
    let try = builtins.tryEval <nixos-unstable>;
    in if try.success
       then builtins.trace "Impure build: Using bleedingEdge"
            (import try.value { config = { allowUnfree = true; }; })
       else builtins.trace "Using pkgs for bleeding edge" pkgs;
  sandbox = pkgs.callPackage ../pkgs/sandbox.nix {};
  all-hies =
    let try = builtins.tryEval <all-hies>;
    in if try.success
       then import try.value {}
       else builtins.trace "Could not find hie channel, using pinned version."
            (import (pkgs.fetchFromGitHub {
              owner = "Infinisil";
              repo = "all-hies";
              rev = "85fd0be92443ca60bb649f8e7748f785fe870b7a";
              sha256 = "0af5grq9szpyyh61zg83dx8ki1i2zqschvs91b1apww414nirlwp";
            }) {});
in
{
  imports = [
    ./Triglav-static.nix
    ../modules
    ../lib
  ];

  environment.systemPackages = (with pkgs; [
    cacert curl git hdparm htop iotop tmux vim wget exfat
    python37Packages.glances
  ]);

  hardware = {
    bluetooth.enable = true;
    bluetooth.package = pkgs.bluezFull;
    pulseaudio.enable = true;
    pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];
    pulseaudio.package = pkgs.pulseaudioFull;

    cpu.intel.updateMicrocode = true;

    opengl.enable = true;
    opengl.extraPackages = with pkgs; [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];
  };

  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;

  i18n.consoleFont = "sun12x22";

  networking.hostName = "Triglav";

  # May prevent evaluation, let's help NixOS by debugging it!
  documentation.nixos.includeAllModules = true;

  nix = {
    binaryCaches = [
      "https://cache.nixos.org/"
      "https://all-hies.cachix.org"
    ];
    binaryCachePublicKeys = [
      "all-hies.cachix.org-1:JjrzAOEUsD9ZMt8fdFbzo3jNAyEWlPAwdVuHw4RD43k="
    ];
    buildCores = 8;
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
    trustedUsers = [ "roosemberth" ];
    gc.automatic = true;
  };
  systemd.services.nix-gc.unitConfig.ConditionACPower = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        inherit all-hies;
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        mymopidy = with pkgs; buildEnv {
          name = "mopidy-with-extensions-${mopidy.version}";
          paths = lib.closePropagation (with pkgs; [
            mopidy-spotify mopidy-iris sandbox.mopidy-mpris
          ]);
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

  programs = {
    bash.enableCompletion = true;
    dconf.enable = true;
    mtr.enable = true;
    wireshark.enable = true;
    wireshark.package = pkgs.wireshark;
  };

  security.sudo = {
    enable = true;
    extraConfig = ''
      %wheel      ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild
      %wheel      ALL=(root) NOPASSWD: /run/current-system/sw/bin/systemctl restart bumblebee
      %wheel      ALL=(root) NOPASSWD: /run/current-system/sw/bin/lsof -nPi
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount -t proc none proc
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount /sys sys -o bind
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount /dev dev -o rbind
      roosemberth ALL=(root) NOPASSWD: /run/current-system/sw/bin/mount -t tmpfs none tmp
    '';
  };
  security.pam.services.login.enableGnomeKeyring = true;

  roos = {
    triglav.network.enable = true;
    udev.enable = true;
    streaming.enable = true;
    user-profiles.roosemberth.enable = true;
    x11.enable = true;
  };

  environment.variables = {
    XDG_CACHE_HOME="\${HOME}/.local/var/cache";
    XDG_CONFIG_HOME="\${HOME}/.local/etc";
    XDG_DATA_HOME="\${HOME}/.local/var/lib";
    XDG_LIB_HOME="\${HOME}/.local/lib";
    XDG_LOG_HOME="\${HOME}/.local/var/log";

    GNUPGHOME="\${XDG_DATA_HOME}/gnupg/";
    GTK2_RC_FILES="\${XDG_CONFIG_HOME}/gtk-2.0/gtkrc-2.0";
    GTK_RC_FILES="\${XDG_CONFIG_HOME}/gtk-1.0/gtkrc";
    PASSWORD_STORE_DIR="\${XDG_DATA_HOME}/pass";
    SSH_AUTH_SOCK="\${XDG_RUNTIME_DIR}/ssh-agent-\${PAM_USER}-socket";
    ZDOTDIR="\${XDG_CONFIG_HOME}/zsh/default";
  };

  users.extraUsers.roosemberth.packages =
  let
  in ((with pkgs; [
      texlive.combined.scheme-full youtube-dl mpv mymopidy
    ]) ++ (with bleedingEdge; [
    ]) ++ (with sandbox; [
    ]) ++ ([
    ])
  );

  services = {
    logind.extraConfig = "HandlePowerKey=ignore";
    logind.lidSwitch = "ignore";
    nginx.enable = true;
    nginx.virtualHosts = {
      localhost.default = true;
      # Default redirect to HTTPs (e.g. socat rec.la testing).
      localhost.extraConfig = "return 301 https://$host$request_uri;";

      "triglav.r.orbstheorem.ch" = {
        root = "/Storage/tmp/shared/";
        locations."/".extraConfig =
          "return 307 /public-web/;";
        locations."/public-web".extraConfig = "autoindex on;";
      };
    };
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        local all all trust
        host all all 127.0.0.1/24 trust
        host all all ::1/128 trust
        host all all 172.17.0.1/24 trust
      '';
    };
    tlp.enable = true;
    upower.enable = true;
  };

  system = {
    stateVersion = "19.09";
    autoUpgrade.enable = true;
  };

  time.timeZone = "Europe/Zurich";

  users.mutableUsers = false;

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
