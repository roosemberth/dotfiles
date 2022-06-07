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
    networkDnsConfig

    # Cannot use module fprintd.nix because I don't want pam support.
    ({pkgs, ...}: {
      services.dbus.packages = [ pkgs.fprintd ];
      environment.systemPackages = [ pkgs.fprintd ];
      systemd.packages = [ pkgs.fprintd ];
    })
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelPackages =  # Override kernel to 5.15 until it becomes stable.
    assert pkgs.lib.versionOlder "5.15" pkgs.linuxPackages.kernel.version;
      pkgs.linuxPackages;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

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

  environment.systemPackages = with pkgs; [ acpi ];

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
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
    daemonIOSchedClass = "idle";
    daemonIOSchedPriority = 7;
    daemonCPUSchedPolicy = "idle";
    package = pkgs.nixUnstable;
    settings.trusted-users = [ "roosemberth" ];
    settings.substituters = [ "https://cache.nixos.org" ];
    # Is this a good idea?
    registry.df.flake.outPath = "/home/roosemberth/ws/1-Repositories/dotfiles";
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
  roos.wireguard.gwServer = "Heimdaalr";

  # Since deploy-rs is not in Nixpkgs, explicitly add it in this host.
  roos.sConfig.home.packages = [ pkgs.deploy-rs.deploy-rs ];

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
      Unit.PartOf = [ "sway-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        ExecStart = "${pkgs.kanshi}/bin/kanshi -c ${cfgFile}";
        Restart = "always";
        RestartSec = "3";
      };
    };
  };

  security.wrappers.wshowkeys.owner = "root";
  security.wrappers.wshowkeys.group = "input";
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
    # Despite being in the xserver namespace, this does not enable any of X11.
    xserver.desktopManager.gnome.enable = true;
    xserver.displayManager.gdm.enable = true;
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      # Default redirect to HTTPs (e.g. socat rec.la testing).
      virtualHosts.localhost = {
        default = true;
        extraConfig = ''
          location /.well-known/acme-challenge/ {
            root /srv/acme;
            allow all;
          }

          location / {
            return 301 https://$host$request_uri;
          }
        '';
      };
      # Reverse proxy for dev stuff
      virtualHosts."iris.rec.la" = {
        onlySSL = true;
        sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
        sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
        basicAuthFile = "/srv/iris.htpasswd";
        locations."/" = {
          proxyPass = "http://127.0.0.1:6680";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
      virtualHosts.".rec.la" = {
        onlySSL = true;
        sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
        sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
        locations."/" = {
          proxyPass = "http://localhost:5000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    };
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    openssh.hostKeys = [
      { path = "/var/lib/secrets/ssh_host_ed25519_key"; type = "ed25519"; }
    ];
    hardware.bolt.enable = true;

    pipewire = {
      pulse.enable = true;
      jack.enable = true;
      alsa.enable = true;
      media-session.enable = true;
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

  system.stateVersion = "21.11";
  system.autoUpgrade.enable = true;

  # Imperative NixOS containers are affected by this.
  systemd.services."container@".serviceConfig.TimeoutStartSec =
    lib.mkForce "20min";
  # Disable network manager wait-online.
  systemd.services."NetworkManager-wait-online".wantedBy = lib.mkForce [];

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
  virtualisation.libvirtd.enable = true;
}
