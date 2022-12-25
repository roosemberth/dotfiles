{ config, pkgs, lib, ... }: let
  bindConfig = let
    zone."orbstheorem.ch" = "/run/named/zones/orbstheorem.ch.zone";
  in {
    networking.firewall.allowedUDPPorts = [53];
    services.bind = {
      enable = true;
      extraConfig = ''
        include "/keyring/dns/dns-orbstheorem.ch.keys.conf";
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };
      '';
      zones = [{
        name = "orbstheorem.ch";
        master = true;
        # Writeable so it can be updated during acme provisioning via rfc2136.
        file = zone."orbstheorem.ch";
        extraConfig = "allow-update { key rfc2136key.orbstheorem.ch.; };";
      }];
    };
    services.prometheus.exporters.bind.enable = true;
    services.prometheus.exporters.bind.bindGroups = [ "server" "view" "tasks" ];
    systemd.services."bind-zone-orbstheorem.ch" = {
      description = "Copy zonefile for orbstheorem.ch from the nix-store.";
      requiredBy = ["bind.service"];
      partOf = ["bind.service"];
      before = ["bind.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          srcfile = config.sops.secrets."services/dns/zones/orbstheorem.ch".path;
          installCmd = "${pkgs.coreutils}/bin/install";
        in pkgs.writeShellScript "copy-zonefile-for-bind" ''
          ${pkgs.coreutils}/bin/rm -fr /run/named/zones
          ${installCmd} -o named -g root -m 0755 -d /run/named/zones
          ${installCmd} -o named -g root -m 0400 -T ${srcfile} ${zone."orbstheorem.ch"}
        '';
      };
    };
    systemd.services.bind.partOf = ["bind-zone-orbstheorem.ch.service"];
    systemd.tmpfiles.rules = [
      "f /keyring/dns/dns-orbstheorem.ch.keys.conf 0400 named root -"
    ];
    sops.secrets."services/dns/zones/orbstheorem.ch" = {};
  };
  acmeConfig = { secrets, ... }: {
    security.acme.acceptTerms = true;
    security.acme.defaults.email = secrets.network.acme.email;
    security.acme.certs."orbstheorem.ch" = {
      extraDomainNames = ["*.orbstheorem.ch" "*.mimir.orbstheorem.ch"];
      group = "certs-orbstheore";
      dnsProvider = "rfc2136";
      credentialsFile = "/keyring/acme/orbstheorem.ch.secret";
      dnsPropagationCheck = false;
    };
    users.groups.certs-orbstheore = {};
    systemd.tmpfiles.rules = [
      "f /keyring/acme/orbstheorem.ch.secret 0400 acme root -"
    ];
  };
  nginxConfig = { secrets, ... }: {
    networking.firewall.allowedTCPPorts = [80 443 8448];
    networking.nat.enable = true;
    networking.nat.externalInterface = "ens3";
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      clientMaxBodySize = "25G";
      eventsConfig = "worker_connections 4096;";
      appendConfig = "worker_rlimit_nofile 4096;";

      virtualHosts = with lib; let
        sslOpts = c: {
          onlySSL = c.onlySSL or true;
          sslCertificate = "/var/lib/acme/orbstheorem.ch/cert.pem";
          sslCertificateKey = "/var/lib/acme/orbstheorem.ch/key.pem";
        };
      in mapAttrs (_: c: c // sslOpts c) {
        "orbstheorem.ch" = {
          default = true;
          onlySSL = false;
          forceSSL = true;
          listen = [
            { addr = "[::]"; port = 80; ssl = false; }
            { addr = "[::]"; port = 443; ssl = true; }
            { addr = "[::]"; port = 8448; ssl = true; }
            { addr = "0.0.0.0"; port = 80; ssl = false; }
            { addr = "0.0.0.0"; port = 443; ssl = true; }
            { addr = "0.0.0.0"; port = 8448; ssl = true; }
          ];
          root = "/var/www/orbstheorem.ch";
          locations."/".extraConfig = ''
            error_page 404 = /404.html;
            index      404.html;
          '';
          locations."~ ^/(_matrix|_synapse/client|.well-known/matrix/)" = {
            proxyPass = "http://minerva.intranet.orbstheorem.ch:8448";
          };
        };

        "monitoring.orbstheorem.ch" = {
          extraConfig = ''
            auth_basic "PPQ 821x blue";
            auth_basic_user_file /keyring/nginx/monitoring.htpasswd;
          '';
          locations."/".proxyPass = "http://minerva.intranet.orbstheorem.ch:9090";
        };

        "alerts.orbstheorem.ch" = {
          extraConfig = ''
            auth_basic "PPQ 821x blue";
            auth_basic_user_file /keyring/nginx/monitoring.htpasswd;
          '';
          locations."/".proxyPass = "http://minerva.intranet.orbstheorem.ch:9093";
        };

        "heig.orbstheorem.ch".locations."/".proxyPass =
          "http://mimir.r.orbstheorem.ch:2270";

        "powerflow.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch:45100";

        "minerva.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch";

        "nextcloud.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch:42080";

        "collabora.orbstheorem.ch".locations."/" = {
          proxyPass = "http://minerva.intranet.orbstheorem.ch:42085";
          proxyWebsockets = true;
        };

        "home.orbstheorem.ch".locations."/" = {
          proxyPass = "http://minerva.intranet.orbstheorem.ch:48080";
          proxyWebsockets = true;
        };

        "files.orbstheorem.ch" = {
          root = "/var/www/files/orbstheorem.ch";
          extraConfig = ''
            add_header X-Frame-Options DENY;
            add_header Strict-Transport-Security max-age=2678400;  # 1 month
          '';

          locations."/".extraConfig = ''
            autoindex off;
            root /var/www/files/orbstheorem.ch/landing;
          '';
          locations."~ ^/(.+?)/(.*)?$".extraConfig = ''
            autoindex on;
            alias /var/www/files/orbstheorem.ch/users/$1/files/$2;
            auth_basic "Speak friend and come in";
            auth_basic_user_file /var/www/files/orbstheorem.ch/users/$1/htpasswd;
          '';
        };

        "public-files.orbstheorem.ch" = {
          root = "/var/www/files/orbstheorem.ch";
          extraConfig = ''
            add_header X-Frame-Options DENY;
            add_header Strict-Transport-Security max-age=2678400;  # 1 month
          '';
          locations."/".extraConfig = ''
            autoindex on;
            root /var/www/files/orbstheorem.ch/public;
          '';
        };

        "amt.mimir.orbstheorem.ch".locations."/".proxyPass =
          "http://mimir.r.orbstheorem.ch:48080";

        "mlg.orbstheorem.ch" = {
          locations."/".proxyPass = "http://minerva.intranet.orbstheorem.ch:8888";
          locations."/".proxyWebsockets = true;
        };

        "~(?<subdomain>[^\\.]*).mimir.orbstheorem.ch".locations."/" = {
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header  X-Real-IP         $remote_addr;
            proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header  Host              "$subdomain.rec.la";
            proxy_set_header  X-Forwarded-Proto https;
            proxy_pass        https://mimir.r.orbstheorem.ch:443;
          '';
        };
      };
    } // secrets.opaque-nginx."orbstheorem.ch";
    # Allow access orbstheorem.ch certs
    systemd.services.nginx.serviceConfig.SupplementaryGroups =
      [ "certs-orbstheore" ];
    systemd.services.nginx.after = ["acme-finished-orbstheorem.ch.target"];
    systemd.services.nginx.requires = ["acme-finished-orbstheorem.ch.target"];
  };
  monitoringConfig = { networks, ... }: {
    services.prometheus.exporters.node.enable = true;
    services.prometheus.exporters.node.enabledCollectors = [ "systemd" ];
    services.prometheus.exporters.node.listenAddress = networks.zkx.dns.v4;
    # Prometheus binds to a wireguard address...
    systemd.services."prometheus-node-exporter".after =
      ["wireguard-Bifrost.service"];
  };
  turnConfig = { lib, secrets, ... }: {
    # Turn traffic
    networking.firewall.allowedUDPPorts = [ 3478 5349 ];
    networking.firewall.allowedTCPPorts = [ 3478 5349 ];
    # UDP Relay
    networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 65535; } ];

    services.coturn = {
      enable = true;
      realm = "turn.orbstheorem.ch";
      use-auth-secret = true;
      static-auth-secret-file = "/run/secrets/coturn/static-auth-secret";
      listening-ips = [ "2a04:52c0:101:2a7::101" "5.255.96.101" ];

      cert = "/var/lib/acme/orbstheorem.ch/cert.pem";
      pkey = "/var/lib/acme/orbstheorem.ch/key.pem";

      min-port = 60000;
      max-port = 65535;
      no-tcp-relay = true;

      extraConfig = ''
        # Deny private network peers
        denied-peer-ip=10.0.0.0-10.255.255.255
        denied-peer-ip=192.168.0.0-192.168.255.255
        denied-peer-ip=172.16.0.0-172.31.255.255
        # TODO: Should we also deny v6 private network?

        # recommended additional local peers to block, to mitigate external
        # access to internal services.
        # https://www.rtcsec.com/article/slack-webrtc-turn-compromise-and-bug-bounty/#how-to-fix-an-open-turn-relay-to-address-this-vulnerability
        no-multicast-peers
        denied-peer-ip=0.0.0.0-0.255.255.255
        denied-peer-ip=100.64.0.0-100.127.255.255
        denied-peer-ip=127.0.0.0-127.255.255.255
        denied-peer-ip=169.254.0.0-169.254.255.255
        denied-peer-ip=192.0.0.0-192.0.0.255
        denied-peer-ip=192.0.2.0-192.0.2.255
        denied-peer-ip=192.88.99.0-192.88.99.255
        denied-peer-ip=198.18.0.0-198.19.255.255
        denied-peer-ip=198.51.100.0-198.51.100.255
        denied-peer-ip=203.0.113.0-203.0.113.255
        denied-peer-ip=240.0.0.0-255.255.255.255

        no-stun

        # 4 streams per video call, so 12 streams = 3 simultaneous relayed calls
        # per user.
        user-quota=12
      '';
    };
    systemd.services.coturn.after = ["acme-finished-orbstheorem.ch.target"];
    systemd.services.coturn.requires = ["acme-finished-orbstheorem.ch.target"];
    systemd.services.coturn.serviceConfig.SupplementaryGroups =
      [ "certs-orbstheore" ];

    sops.secrets."coturn/static-auth-secret" = {
      owner = config.users.users.turnserver.name;
      group = config.users.groups.turnserver.name;
    };
  };
in {
  imports = [
    ../modules
    ./Heimdaalr-static.nix
    acmeConfig
    bindConfig
    nginxConfig
    monitoringConfig
    turnConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions

  environment.systemPackages = [ pkgs.nvim-roos-essential ];

  networking.hostName = "Heimdaalr";
  networking.useNetworkd = true;
  networking.useDHCP = false;

  nix.extraOptions = "experimental-features = nix-command flakes";
  nix.package = pkgs.nixUnstable;
  nix.trustedUsers = [ "roosemberth" ];

  roos.dotfilesPath = ../..;
  roos.user-profiles.reduced = ["roosemberth"];
  roos.wireguard.enable = true;

  security.pam.enableSSHAgentAuth = true;
  services = {
    openssh.enable = true;
    openssh.gatewayPorts = "yes";
    openssh.extraConfig = "PermitTunnel yes";
    netdata.enable = true;
    resolved.llmnr = "false";
  };
  system.stateVersion = "21.11";

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
}
