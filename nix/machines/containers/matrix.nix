{ config, pkgs, lib, secrets, ... }: let
  fsec = config.sops.secrets;
in {
  containers.matrix = {
    autoStart = true;
    bindMounts.matrix-synapse.hostPath =
      config.roos.container-host.guestMounts.matrix-synapse.hostPath;
    bindMounts.matrix-synapse.mountPoint = "/var/lib/matrix-synapse";
    bindMounts.matrix-synapse.isReadOnly = false;
    bindMounts."/run/secrets/services/matrix" = {};
    bindMounts."/run/secrets/services/matrix_appservice_discord" = {};
    config = {
      networking.firewall.allowedTCPPorts = [ 8448 9092 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.firewall.extraCommands = ''
        ip6tables -I nixos-fw -s fe80::/64 -p udp -m udp --dport 5355 -j ACCEPT
      '';

      # The host network cannot handle the DNS traffic from Matrix...
      networking.nameservers = with secrets.network.zksDNS; v4;
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      systemd.services.systemd-networkd-wait-online = lib.mkForce {};

      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";

      # Inherit host nix package set
      nix.nixPath = [ "/etc/nix/system-evaluation-inputs" ];
      nix.registry = {
        inherit (config.nix.registry) nixpkgs p;
      };
      environment.etc = {
        inherit (config.environment.etc) "nix/system-evaluation-inputs/nixpkgs";
      };

      services.matrix-synapse.enable = true;
      services.matrix-synapse.dataDir = "/var/lib/matrix-synapse";
      services.matrix-synapse.settings = {
        server_name = "orbstheorem.ch";
        listeners = [{
          port = 8448;
          resources = [{ names = [ "client" "federation" ]; compress = true; }];
          bind_addresses = [ "0.0.0.0" ];
          tls = false;
          x_forwarded = true;
        } {
          port = 9092;
          type = "metrics";
          resources = [];
          # IPv6 seems unsupported for metrics-listener
          # https://github.com/matrix-org/synapse/issues/6644
          bind_addresses = [ "0.0.0.0" ];
          tls = false;
        }];
        trusted_key_servers = [{
          server_name = "pacien.net";
          verify_keys."ed25519:a_fhhB" =
            "N8ZVXJG7CSnCK1+rthEmvoDo1tPlQC5bxcJuPA+/RZs";
        } {
          server_name = "gnugen.ch";
          verify_keys."ed25519:a_bPqV" =
          "1NrywDVt85bq5qLeInMXgUY+Y7f7Lqza6XGpV5viPpU";
        } {
          server_name = "matrix.org";
          verify_keys."ed25519:auto" =
          "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
        }];
        enable_metrics = true;
        max_upload_size = "100M";
        url_preview_enabled = true;
        report_stats = true;
        tls_certificate_path = fsec."services/matrix/tls_certificate".path;
        tls_private_key_path = fsec."services/matrix/tls_private_key".path;
        inherit (secrets.matrix)
          turn_uris
          turn_shared_secret
          database
          registration_shared_secret
          ;
        app_service_config_files = [
          fsec."services/matrix_appservice_discord/registration".path
        ];
      };
      systemd.services.link-discord-appservice-registration = {
        description = "Link discord's appservice registration";
        requiredBy = [ "matrix-appservice-discord.service" ];
        before = [ "matrix-appservice-discord.service" ];
        path = with pkgs; [ acl  ];
        serviceConfig.ExecStart = builtins.toString
          (pkgs.writeShellScript "fix-appservice-perms" (''
            # Workaround the NixOS module...
            mkdir -p /var/lib/private/matrix-appservice-discord
            cd /var/lib/private/matrix-appservice-discord
            cp ${fsec."services/matrix_appservice_discord/registration".path} \
              discord-registration.yaml
            chmod 444 discord-registration.yaml
        ''));
      };
      services.matrix-appservice-discord = {
        enable = true;
        settings = {
          bridge.domain = "orbstheorem.ch";
          bridge.homeserverUrl = "https://orbstheorem.ch";
          bridge.adminMxid = "@roosemberth:orbstheorem.ch";
          bridge.disableJoinLeaveNotifications = true;
          inherit (secrets.matrix_appservice_discord) database;
          channel.namePattern = ":guild :name";
        };
        serviceDependencies = [ "matrix-synapse.service" ];
        # Read by systemd, so we don't care about permissions.
        environmentFile = fsec."services/matrix_appservice_discord/env".path;
      };
      system.stateVersion = "22.05";
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.4/24";
    hostBridge = "orion";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 8448; protocol = "tcp"; }
      { hostPort = 9092; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.matrix = {
    in-rules = [
      # DNS
      "-p udp -m udp --dport 53 -j ACCEPT"
      # Database
      "-p tcp -m tcp --dport 5432 -j ACCEPT"
    ];
    ipv4.fwd-rules = [
      # Replies to the reverse proxy
      "-d 10.13.255.101/32 -m state --state RELATED,ESTABLISHED -j ACCEPT"
      # Replies from metrics port
      "-d 10.231.136.0/24 -m state --state RELATED,ESTABLISHED -p tcp --sport 9092 -j ACCEPT"
      # Use zkx DNS resolver
      "-d 10.13.0.0/16 -p udp -m udp --dport 53 -j ACCEPT"
    ];
  };
  roos.container-host.guestMounts.matrix-synapse = {};

  sops.secrets = let
    secretCfg = {
      restartUnits = [ "container@matrix.service" ];
      # We cannot set the required owner and group since the target values don't
      # exist in the host configuration, thus failing the activation script.
    };
  in {
    "services/matrix/tls_dh_params" = secretCfg;
    "services/matrix/tls_certificate" = secretCfg;
    "services/matrix/tls_private_key" = secretCfg;
    "services/matrix_appservice_discord/env" = secretCfg;
    "services/matrix_appservice_discord/registration" = secretCfg;
  };

  system.activationScripts.secretsForMatrix = let
    o = toString config.containers.matrix.config.users.users.matrix-synapse.uid;
    g = toString config.containers.matrix.config.users.groups.matrix-synapse.gid;
  in lib.stringAfter ["setupSecrets"] ''
    chown ${o}:${g} "${fsec."services/matrix/tls_dh_params".path}"
    chown ${o}:${g} "${fsec."services/matrix/tls_certificate".path}"
    chown ${o}:${g} "${fsec."services/matrix/tls_private_key".path}"
    chown ${o}:${g} "${fsec."services/matrix_appservice_discord/registration".path}"
  '';
}
