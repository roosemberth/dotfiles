{ config, pkgs, lib, ... }: let
  bindConfig = { secrets, ... }: let
    zone."orbstheorem.ch" = "/run/named/zones/orbstheorem.ch.zone";
  in {
    networking.firewall.allowedUDPPorts = [53];
    services.bind = {
      enable = true;
      extraConfig = ''
        include "/keyring/dns/dns-orbstheorem.ch.keys.conf";
      '';
      zones = [{
        name = "orbstheorem.ch";
        master = true;
        # Writeable so it can be updated during acme provisioning via rfc2136.
        file = zone."orbstheorem.ch";
        extraConfig = "allow-update { key rfc2136key.orbstheorem.ch.; };";
      }];
    };
    systemd.services."bind-zone-orbstheorem.ch" = {
      description = "Copy zonefile for orbstheorem.ch from the nix-store.";
      requiredBy = ["bind.service"];
      partOf = ["bind.service"];
      before = ["bind.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          srcfile = secrets.network.bind-zones."orbstheorem.ch";
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
  };
  acmeConfig = { secrets, ... }: {
    security.acme.acceptTerms = true;
    security.acme.email = secrets.network.acme.email;
    security.acme.certs."orbstheorem.ch" = {
      extraDomainNames = ["*.orbstheorem.ch" "*.mimir.orbstheorem.ch"];
      group = "nginx";
      dnsProvider = "rfc2136";
      credentialsFile = "/keyring/acme/orbstheorem.ch.secret";
      dnsPropagationCheck = false;
    };
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
          locations."~ ^/(_matrix|.well-known/matrix/)" = {
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

        "heig.orbstheorem.ch".locations."/".proxyPass =
          "http://mimir.r.orbstheorem.ch:2270";

        "greenzz.orbstheorem.ch" = {
          locations."/".proxyPass = "http://minerva.intranet.orbstheorem.ch:43000";
          locations."/grafana/".proxyPass =
            "http://minerva.intranet.orbstheorem.ch:43001";
          locations."/public/pro/".proxyPass =
            "http://minerva.intranet.orbstheorem.ch:43003";
        };

        "powerflow.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch:45100";

        "minerva.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch";

        "nextcloud.orbstheorem.ch".locations."/".proxyPass =
          "http://minerva.intranet.orbstheorem.ch:42080";

        "files.orbstheorem.ch" = {
          root = "/var/www/files.orbstheorem.ch";
          extraConfig = ''
            add_header X-Frame-Options DENY;
            add_header Strict-Transport-Security max-age=2678400;  # 1 month
          '';

          locations."/".extraConfig = ''
            autoindex off;
            root /var/www/files/orbstheorem.ch/landing;
          '';
          locations."/public/".extraConfig = "autoindex on;";
          locations."~ ^/(.+?)/(.*)?$".extraConfig = ''
            autoindex on;
            alias users/$1/files/$2;
            auth_basic "Speak friend and come in";
            auth_basic_user_file /var/www/files.orbstheorem.ch/users/$1/htpasswd;
          '';
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
    systemd.services.nginx.after = ["acme-finished-orbstheorem.ch.target"];
    systemd.services.nginx.requires = ["acme-finished-orbstheorem.ch.target"];
  };
in {
  imports = [
    ../modules
    ./Heimdaalr-static.nix
    acmeConfig
    bindConfig
    nginxConfig
  ];

  boot.cleanTmpDir = true;
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = 2;  # Enable YAMA restrictions

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
