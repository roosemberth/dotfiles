{ config, pkgs, lib, ... }:
let
  nixpkgs-master =
    let try = builtins.tryEval <nixpkgs-git>;
    in if try.success then import try.value
    else builtins.trace "Using pkgs for nixpkgs-master" import (
      builtins.fetchGit {
          url = "https://github.com/nixos/nixpkgs.git";
          rev = "700ce1fd8128c08c1b2b1d66a6c5b38e75042a13";
      });
  nixpkgs-wayland =
    let try = builtins.tryEval <nixpkgs-wayland>;
    in if try.success then import try.value
    else builtins.trace "Using pinned version of nixpkgs-wayland" import (
      builtins.fetchGit {
          url = "https://github.com/colemickens/nixpkgs-wayland.git";
          rev = "3b676534975874a41ba689fd20f623550fb59b32";
      });
  bleeding-edge = nixpkgs-master { overlays = [ nixpkgs-wayland ]; };
  vim' = pkgs.writeShellScriptBin "vim" ''exec ${pkgs.neovim}/bin/nvim "$@"'';
in
{
  imports = [
    ../modules
    ./Mimir-static.nix
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernelModules = [ "kvm-intel" ];

  environment.systemPackages = (with pkgs; [
    cacert curl git hdparm htop iotop tmux neovim vim' wget exfat
    glances posix_man_pages nfsUtils
  ]);

  fonts.fonts = with pkgs; [
    hack-font
    noto-fonts
    noto-fonts-emoji
    noto-fonts-extra
    powerline-fonts
    profont
    source-code-pro
    terminus_font_ttf
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.package = pkgs.bluezFull;
    pulseaudio.enable = true;
    pulseaudio.extraModules = [ pkgs.pulseaudio-modules-bt ];
    pulseaudio.package = pkgs.pulseaudioFull;

    sane.enable = true;
    cpu.intel.updateMicrocode = true;

    opengl.enable = true;
    opengl.extraPackages = with pkgs; [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];
  };

  networking.hostName = "Mimir";
  networking.networkmanager.enable = true;

  nix = {
    binaryCaches = [
      "https://cache.nixos.org"
      "https://nixpkgs-wayland.cachix.org"
    ];
    binaryCachePublicKeys = [
      "nixpkgs-wayland.cachix.org-1:3lwxalLxMRkVhehr5StQprHdEo4lrE8sRho9R9HOLYA="
    ];
  };

  nixpkgs = {
    config = {
      packageOverrides = pkgs: {
        inherit bleeding-edge;
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        sway = bleeding-edge.sway;
      };
    };
  };

  programs = {
    bash.enableCompletion = true;
    dconf.enable = true;
    mtr.enable = true;
    sway.enable = true;
    wireshark.enable = true;
    wireshark.package = pkgs.wireshark;
  };

  roos.dotfilesPath = ../..;
  roos.media.enable = true;
  roos.steam.enable = true;
  roos.user-profiles.graphical = ["roosemberth"];
  roos.wayland.enable = true;

  services = {
    logind.extraConfig = "HandlePowerKey=ignore";
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    tlp.enable = true;
    upower.enable = true;
  };

  system.stateVersion = "19.09";
  # Not as long as we're running on nixpkgs-unstable
  # system.autoUpgrade.enable = true;

  time.timeZone = "Europe/Zurich";

  users = {
    mutableUsers = false;
    motd = with config; ''
      Welcome to ${networking.hostName}

      - This machine is managed by NixOS
      - All changes are futile

      OS:      NixOS ${system.nixos.release} (${system.nixos.codeName})
      Version: ${system.nixos.version}
      Kernel:  ${boot.kernelPackages.kernel.version}
    '';
  };

  virtualisation.libvirtd.enable = true;
  virtualisation.docker.enable = true;
}
