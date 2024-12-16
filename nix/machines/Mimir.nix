{ config, pkgs, lib, ... }:
let
  networkDnsConfig =
    { networks, ... }:
    {
      networking.networkmanager.dns = "systemd-resolved";
      networking.search = [ "zkx.ch" "int.zkx.ch" ];
      networking.firewall.allowedUDPPorts = [ 5355 ]; # LLMNR responses
      services.tailscale.enable = true;
      services.resolved = {
        enable = true;
        llmnr = "true";
        dnssec = "false";
        extraConfig = with lib; let
          dnsZones = [ "dyn.zkx.ch" "zkx.ch" ];
          dnsSrvs = with networks.zkx.dns; ["[${v6}]" v4];
          netXsrv = cartesianProductOfSets { net = dnsZones; srv = dnsSrvs; };
        in "DNS=" + concatMapStringsSep " " (x: "${x.srv}#${x.net}") netXsrv;
      };
    };
in {
  imports = [
    ./Mimir-static.nix
    networkDnsConfig
  ];

  boot.tmp.cleanOnBoot = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions
  boot.kernel.sysctl."kernel.sysrq" = 240;  # Enable sysrq
  boot.kernelModules = [ "kvm-intel" "ddcci-backlight" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  fonts.packages = with pkgs; [
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
  environment.gnome.excludePackages = with pkgs; [
    orca gnome-backgrounds gnome-color-manager gnome-shell-extensions
    gnome-tour gnome-user-docs orca gnome-menus
  ];

  hardware = {
    bluetooth.enable = true;
    bluetooth.package = pkgs.bluez;

    cpu.intel.updateMicrocode = true;
    ledger.enable = true;
    digitalbitbox.enable = true;

    graphics.enable = true;
    graphics.extraPackages = with pkgs; [
      intel-media-driver
      libvdpau-va-gl
      rocmPackages.clr.icd
      vaapiIntel
      vaapiVdpau
    ];

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
    adb.enable = true;
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
  roos.hyprland.enable = true;
  roos.cosmic.enable = true;
  roos.wireguard.enable = true;
  roos.wireguard.network = "bifrost-via-heimdaalr";

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
        profile bity {
          output eDP-1 disable
          output "Ancor Communications Inc ASUS PB287Q 0x0000CE31" enable scale 1.5
        }
      '';
    in lib.mkIf hmCfg.sessions.sway.enable {
      Unit.Description = "Kanshi screen output profile daemon";
      Unit.PartOf = [ "sway-session.target" ];
      Install.WantedBy = [ "sway-session.target" ];
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
      virtualHosts."~^(?!priv-)(?<service>[^.]+?)\\.rec.la$" = {
        onlySSL = true;
        sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
        sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
        extraConfig = ''
          # Optional authentication
          set $service_htpasswd /srv/$service.htpasswd;
          if (!-f $service_htpasswd) {
              return 599;
          }
          error_page 599 = @noauth;
        '';
        locations."/" = {
          proxyPass = "http://localhost:5000";
          proxyWebsockets = true;
          extraConfig = ''
            auth_basic "Blue 37 Orchid.";
            auth_basic_user_file $service_htpasswd;
            proxy_buffering off;
          '';
        };
        locations."@noauth" = {
          proxyPass = "http://localhost:5000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
      virtualHosts."~^priv-(?<service>[^.]+?)\\.rec.la$" = {
        onlySSL = true;
        sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
        sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
        locations."/" = {
          proxyPass = "http://localhost:5001";
          proxyWebsockets = true;
        };
      };
    };
    openssh.enable = true;
    openssh.settings.GatewayPorts = "yes";
    openssh.hostKeys = [
      { path = "/var/lib/secrets/ssh_host_ed25519_key"; type = "ed25519"; }
    ];
    hardware.bolt.enable = true;

    pipewire = {
      alsa.enable = true;
      jack.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    tlp.enable = true;
    power-profiles-daemon.enable = false;  # Conflicts with TLP
    udev.extraHwdb = ''
      evdev:input:b0018v056Ap0000*
       EVDEV_ABS_00=::20
       EVDEV_ABS_01=::20
    '';
    udev.extraRules = let
      extend = ext: r: lib.recursiveUpdate ext r;
      netrules =
        (map (extend { match."ACTION" = "add"; }) [
          # Rename wireless card
          { match."ENV{ID_NET_NAME_MAC}" = "wlx84c5a62adf55"; 
            make."NAME" = { operator = ":="; value = "wlan"; };
          }
          # Rename built-in interface with proprietary connector
          { match."KERNEL" = "enp0s31f6";
            make."NAME" = { operator = ":="; value = "useless"; };
          }
          # Rename interface created by the librem5
          { match."ENV{ID_VENDOR_ENC}" = "Purism\\x2c\\x20SPC";
            match."ENV{ID_MODEL_ENC}" = "Librem\\x205";
            make."NAME" = { operator = ":="; value = "l5"; };
          }
        ]);
    in ''
      SUBSYSTEM!="net", GOTO="net_rules_end"
      ${lib.concatMapStringsSep "\n" config.lib.udev.renderRule netrules}
      LABEL="net_rules_end"
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
}
