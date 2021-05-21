{ config, pkgs, lib, ... }:
let
  # Hack since secrets are not available to the machine top-level definition...
  networkDnsConfig =
    { secrets, ... }:
    {
      environment.etc."NetworkManager/dnsmasq.d/10-mimir-local.conf".text =
        with secrets.network; with lib; let
          dnsZones = map (p: p.name) allDnsZones;
          dnsSrvs = zksDNS.v6 ++ zksDNS.v4;
          cfgLine = net: ip: "server=/${net}/${ip}";
        in concatStringsSep "\n" (crossLists cfgLine [dnsZones dnsSrvs]);
      networking.networkmanager.dns = "dnsmasq";
      networking.search = with secrets.network.zksDNS; [ search "int.${search}" ];
    };
in {
  imports = [
    ../modules
    ./Mimir-static.nix
    ./specialisations/Mimir.nix
    networkDnsConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
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

    cpu.intel.updateMicrocode = true;

    opengl.enable = true;
    opengl.extraPackages = with pkgs;
      [ vaapiIntel vaapiVdpau libvdpau-va-gl intel-media-driver ];

    pulseaudio.enable = false;
  };

  networking.hostName = "Mimir";
  networking.networkmanager.enable = true;

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
    trustedUsers = [ "roosemberth" ];
    # Is this a good idea?
    registry.df.flake.outPath = "/home/roosemberth/ws/1-Repositories/dotfiles";
  };

  nixpkgs = {
    config = {
      packageOverrides = p: {
        vaapiIntel = p.vaapiIntel.override { enableHybridCodec = true; };
        firejail = assert p.firejail.version == "0.9.64.4";
                   p.firejail.overrideAttrs(o: {
          patches = (o.patches or []) ++ [ ./enable-overlayfs.patch ];
        });
      };
    };
  };

  programs = {
    dconf.enable = true;
    firejail.enable = true;
    wireshark.enable = true;
    wireshark.package = pkgs.wireshark;
  };

  roos.agenda.enable = true;
  roos.dev.enable = true;
  roos.dotfilesPath = ../..;
  roos.eivd.enable = true;
  roos.media.enable = true;
  roos.nginx-fileshare.enable = true;
  roos.nginx-fileshare.directory = "/srv/shared";
  roos.steam.enable = true;
  roos.user-profiles.graphical = ["roosemberth"];
  # roos.gConfig = {
  #   services.kdeconnect.enable = true;
  # };
  roos.sway.enable = true;
  roos.wireguard.enable = true;
  roos.wireguard.gwServer = "Hellendaal";

  security.wrappers.wshowkeys.source = "${pkgs.wshowkeys}/bin/wshowkeys";
  security.sudo.extraConfig = ''
    roosemberth ALL=(postgres) NOPASSWD: /run/current-system/sw/bin/psql
  '';

  services = {
    gvfs.enable = true;
    logind.extraConfig = ''
      HandlePowerKey=ignore
      RuntimeDirectorySize=95%
    '';
    nginx.enable = true;
    # Default redirect to HTTPs (e.g. socat rec.la testing).
    nginx.virtualHosts.localhost = {
      default = true;
      extraConfig = "return 301 https://$host$request_uri;";
    };
    openssh.enable = true;
    openssh.gatewayPorts = "yes";

    pipewire = {
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      media-session.enable = true;
      media-session.config.bluez-monitor.rules = [
        { # Matches all bluetooth cards
          matches = [ { "device.name" = "~bluez_card.*"; } ];
          actions."update-props" = {
            "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
            # mSBC is not expected to work on all headset + adapter combinations.
            "bluez5.msbc-support" = true;
          };
        }
        {
          actions."node.pause-on-idle" = false;
          matches = [
            { "node.name" = "~bluez_input.*"; }
            { "node.name" = "~bluez_output.*"; }
          ];
        }
      ];
    };

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
    power-profiles-daemon.enable = false;  # Conflicts with TLP
    udev.extraHwdb = ''
      evdev:input:b0018v056Ap0000*
       EVDEV_ABS_00=::20
       EVDEV_ABS_01=::20
    '';
    udev.extraRules = ''
      # Rename built-in interface with proprietary connector
      SUBSYSTEM=="net",ACTION=="add",KERNEL=="enp0s31f6",NAME="useless"
    '';
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
