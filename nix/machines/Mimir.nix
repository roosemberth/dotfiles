{ config, pkgs, lib, ... }:
let
  # Hack since secrets are not available to the machine top-level definition...
  networkDnsConfig =
    { secrets, ... }:
    {
      networking.networkmanager.dns = "systemd-resolved";
      networking.search = with secrets.network.zksDNS; [ search "int.${search}" ];
      networking.firewall.allowedUDPPorts = [ 5355 ]; # LLMNR responses
      services.resolved = {
        enable = true;
        llmnr = "true";
        dnssec = "false";
        extraConfig = with secrets.network; with lib; let
          dnsZones = map (p: p.name) allDnsZones;
          dnsSrvs = (map (ip: "[${ip}]") zksDNS.v6) ++ zksDNS.v4;
          netXsrv = cartesianProductOfSets { net = dnsZones; srv = dnsSrvs; };
        in "DNS=" + concatMapStringsSep " " (x: "${x.srv}#${x.net}") netXsrv;
      };
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
    daemonNiceLevel = 19;
    daemonIONiceLevel = 7;
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

  # Output profiles
  roos.gConfigFn = hmCfg: {
    config.systemd.user.services.kanshi = let
      cfgFile = pkgs.writeText "kanshi.conf" ''
        profile home {
          output eDP-1 disable
          output "Lenovo Group Limited LEN P44w-10 0x00000101" enable
        }
        profile nomad {
          output eDP-1 enable scale 1.5
        }
      '';
    in lib.mkIf hmCfg.sessions.sway.enable {
      Unit.Description = "Kanshi screen output profile daemon";
      Unit.PartOf = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.kanshi}/bin/kanshi -c ${cfgFile}";
        Restart = "always";
        RestartSec = "3";
      };
    };
  };

  security.wrappers.wshowkeys.source = "${pkgs.wshowkeys}/bin/wshowkeys";
  security.sudo.extraConfig = ''
    roosemberth ALL=(postgres) NOPASSWD: /run/current-system/sw/bin/psql
  '';

  services = {
    flatpak.enable = true;
    gvfs.enable = true;
    logind.extraConfig = ''
      HandlePowerKey=ignore
      RuntimeDirectorySize=95%
    '';
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      # Default redirect to HTTPs (e.g. socat rec.la testing).
      virtualHosts.localhost = {
        default = true;
        extraConfig = "return 301 https://$host$request_uri;";
      };
      # Reverse proxy for dev stuff
      virtualHosts.".rec.la" = {
        onlySSL = true;
        sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
        sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
        locations."/" = {
          proxyPass = "http://localhost:5000";
          proxyWebsockets = true;
        };
      };
    };
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    hardware.bolt.enable = true;

    pipewire = {
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      media-session.enable = true;
      media-session.config.bluez-monitor.rules = [{
        # Matches all bluetooth cards
        matches = [ { "device.name" = "~bluez_card.*"; } ];
        actions."update-props" = {
          "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
          # mSBC is not expected to work on all headset + adapter combinations.
          "bluez5.msbc-support" = true;
        };
      } {
        matches = [
          { "node.name" = "~bluez_input.*"; }
          { "node.name" = "~bluez_output.*"; }
        ];
        actions."node.pause-on-idle" = false;
      }];
      media-session.config.alsa-monitor.rules = [{
        matches = [{
          "node.description" =
            "Cannon Point-LP High Definition Audio Controller Speaker + Headphones";
        }];
        actions."update-props"."node.description" = "Laptop DSP";
        actions."update-props"."node.nick" = "Laptop audio";
        # Workaround odd bug on the session-manager where output will start in bad state.
        actions."update-props"."api.acp.autoport" = true;
      }{
        matches = [{
          "node.description" =
            "Cannon Point-LP High Definition Audio Controller Digital Microphone";
        }];
        actions."update-props"."node.description" = "Laptop Mic";
        actions."update-props"."node.nick" = "Laptop mic";
      }{
        matches = [{
          "node.description" = "~Cannon Point-LP High Definition Audio.*";
        }];
        actions."update-props"."node.pause-on-idle" = true;
      }];
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
      SUBSYSTEM=="net",ACTION=="add",ENV{ID_NET_NAME_MAC}=="wlx84c5a62adf55",NAME:="wlan"
      # Rename built-in interface with proprietary connector
      SUBSYSTEM=="net",ACTION=="add",KERNEL=="enp0s31f6",NAME="useless"
      # Rename interface created by the librem5
      SUBSYSTEM=="net",ACTION=="add",ENV{ID_VENDOR_ENC}=="Purism\x2c\x20SPC",ENV{ID_MODEL_ENC}=="Librem\x205",NAME:="l5"
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

  virtualisation.docker.enable = true;
}
