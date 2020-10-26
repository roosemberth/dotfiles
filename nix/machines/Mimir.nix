{ config, pkgs, lib, ... }:
{
  imports = [
    ../modules
    ./Mimir-static.nix
  ];

  # This can be removed when the default kernel is at least version 5.6
  # https://github.com/NixOS/nixpkgs/pull/86168
  boot.kernelPackages = assert lib.versionOlder pkgs.linux.version "5.6";
    (lib.mkDefault pkgs.linuxPackages_latest);

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernelModules = [ "kvm-intel" ];

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
    # This can be removed when PulseAudio is at least version 14
    # https://wiki.archlinux.org/index.php/Lenovo_ThinkPad_X1_Carbon_(Gen_7)#Audio
    pulseaudio.extraConfig =
      assert lib.versionOlder config.hardware.pulseaudio.package.version "14";
    ''
      load-module module-alsa-sink   device=hw:0,0 channels=4
      load-module module-alsa-source device=hw:0,6 channels=4
    '';

    cpu.intel.updateMicrocode = true;

    opengl.enable = true;
    opengl.extraPackages = with pkgs;
      [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];
  };

  networking.hostName = "Mimir";
  networking.networkmanager.enable = true;
  networking.networkmanager.packages =
    with pkgs.gnome3; [ networkmanager-openconnect ];

  nix = {
    binaryCaches = [
      "https://cache.nixos.org"
    ];
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    package = pkgs.nixUnstable;
  };

  nixpkgs = {
    config = {
      packageOverrides = p: {
        vaapiIntel = p.vaapiIntel.override { enableHybridCodec = true; };
      };
    };
  };

  programs = {
    dconf.enable = true;
    sway.enable = true;
    wireshark.enable = true;
    wireshark.package = pkgs.wireshark;
  };

  roos.agenda.enable = true;
  roos.dev.enable = true;
  roos.dotfilesPath = ../..;
  roos.media.enable = true;
  roos.steam.enable = true;
  roos.user-profiles.graphical = ["roosemberth"];
  # roos.gConfig = {
  #   services.kdeconnect.enable = true;
  # };
  roos.wayland.enable = true;
  roos.wireguard.enable = true;
  roos.wireguard.gwServer = "Hellendaal";

  security.sudo.extraConfig = ''
    roosemberth ALL=(postgres) NOPASSWD: /run/current-system/sw/bin/psql
  '';

  services = {
    logind.extraConfig = ''
      HandlePowerKey=ignore
      RuntimeDirectorySize=95%
    '';
    nginx.enable = true;
    nginx.virtualHosts = {
      localhost.default = true;
      # Default redirect to HTTPs (e.g. socat rec.la testing).
      localhost.extraConfig = "return 301 https://$host$request_uri;";
      "${config.networking.hostName}.orbstheorem.ch" = {
        root = "/srv/shared";
        locations."/".extraConfig = "return 307 /web/;";
        locations."/web".extraConfig = "autoindex on;";
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

  system.stateVersion = "19.09";
  system.autoUpgrade.enable = true;

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
