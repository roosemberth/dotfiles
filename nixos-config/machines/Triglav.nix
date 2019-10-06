{ config, pkgs, lib, mylib, ... }:

let
  bleedingEdge =
    let try = builtins.tryEval <nixos-unstable>;
    in if try.success then (import try.value { config = { allowUnfree = true; }; })
       else builtins.trace "Using pkgs for bleeding edge" pkgs;
  sandbox = pkgs.callPackage ../pkgs/sandbox.nix {};
in
{
  imports = [
    ./Triglav-static.nix
    ../modules
    ../lib
  ];

  environment.systemPackages = (with pkgs; [
    vim curl zsh git tmux htop atop iotop cacert
  ]);

  hardware = {
    bluetooth.enable = true;
    bluetooth.package = pkgs.bluezFull;
    pulseaudio.enable = true;
    pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];
    pulseaudio.package = pkgs.pulseaudioFull;

    cpu.intel.updateMicrocode = true;
  };

  i18n.consoleFont = "sun12x22";

  networking = rec {
    hostName = "Triglav"; # Define your hostname.
    wireguard.interfaces."Bifrost" = mylib.wireguard.mkWireguardCfgForHost hostName;
  };

  nix = {
    binaryCaches = [
      "https://cache.nixos.org/"
      "https://all-hies.cachix.org"
    ];
    binaryCachePublicKeys = [
      "all-hies.cachix.org-1:JjrzAOEUsD9ZMt8fdFbzo3jNAyEWlPAwdVuHw4RD43k="
    ];
    buildCores = 8;
    trustedUsers = [ "roosemberth" ];
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        all-hies = import (fetchTarball "https://github.com/infinisil/all-hies/tarball/master") {};
        mymopidy = with pkgs; buildEnv {
          name = "mopidy-with-extensions-${mopidy.version}";
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
    nginx.virtualHosts.localhost.default = true;
    # Default redirect to HTTPs (e.g. socat rec.la testing).
    nginx.virtualHosts.localhost.extraConfig = "return 301 https://$server_name$request_uri;";
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    postgresql = {
      enable = true;
      enableTCPIP = true;
      authentication = pkgs.lib.mkOverride 10 ''
        local all all trust
        host all all ::1/128 trust
        host all all 172.17.0.1/24 trust
      '';
    };
    tlp.enable = true;
    upower.enable = true;
  };

  system = {
    stateVersion = "18.03";
    autoUpgrade.enable = true;
    copySystemConfiguration = true;
  };

  time.timeZone = "Europe/Zurich";

  users.mutableUsers = false;

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
}
