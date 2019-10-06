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
    wget vim curl zsh git tmux htop atop iotop cacert
  ]);

  hardware = {
    bluetooth.enable = true;
    cpu.intel.updateMicrocode = true;
    pulseaudio.enable = true;
    pulseaudio.package = pkgs.pulseaudioFull;

    bumblebee.enable = true;
    bumblebee.connectDisplay = true;
    nvidia.modesetting.enable = true;
  };

  i18n.consoleFont = "sun12x22";

  networking = rec {
    hostName = "Triglav"; # Define your hostname.
    wireguard.interfaces."Bifrost" = mylib.wireguard.mkWireguardCfgForHost hostName;
  };

  nix = {
    buildCores = 8;
    trustedUsers = [ "roosemberth" ];
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      packageOverrides = pkgs: {
        mymopidy = with bleedingEdge; buildEnv {
          name = "mopidy-with-extensions";
          paths = lib.closePropagation (with bleedingEdge; [mopidy-spotify mopidy-iris]);
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
    extraConfig = ''%wheel  ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild'';
  };
  security.pam.services.login.enableGnomeKeyring = true;

  roos = {
    firewall.enable = true;
    udev.enable = true;
    user-profiles.roosemberth.enable = true;
    x11.enable = true;
  };

  users.extraUsers.roosemberth.packages = ((with pkgs; [
      kdeconnect mpv youtube-dl
    ]) ++ (with bleedingEdge; [
    ]) ++ (with sandbox; [
      indicator-kdeconnect
    ])
  );

  services = {
    logind.extraConfig = ''
      HandlePowerKey="ignore"
    '';
    logind.lidSwitch = "ignore";
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    postgresql.enable = true;
    redshift.enable = true;
    redshift.latitude = "47.36";
    redshift.longitude = "8.55";
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
