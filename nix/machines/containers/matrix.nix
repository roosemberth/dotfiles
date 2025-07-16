{ config, pkgs, lib, networks, roosModules, ... }: let
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
      imports = roosModules;
      networking.firewall.allowedTCPPorts = [ 8448 ];
      networking.interfaces.eth0.ipv4.addresses = [
        { address = "10.231.136.4"; prefixLength = 24; }
      ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.firewall.extraCommands = ''
        ip6tables -I nixos-fw -s fe80::/64 -p udp -m udp --dport 5355 -j ACCEPT
      '';

      # The host network cannot handle the DNS traffic from Matrix...
      networking.nameservers = with networks.zkx.dns; [v6 v4];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      systemd.services.systemd-networkd-wait-online = lib.mkForce {};

      nix.extraOptions = "experimental-features = nix-command flakes";

      # Inherit host nix package set
      nix.nixPath = [ "/etc/nix/system-evaluation-inputs" ];
      nix.registry = {
        inherit (config.nix.registry) nixpkgs p;
      };
      environment.etc = {
        inherit (config.environment.etc) "nix/system-evaluation-inputs/nixpkgs";
      };

      roos.firewall.networks.lan = {
        ifaces.eth0 = {};
        in6-rules = [
          "-p udp -m udp --dport 5355 -j ACCEPT" # LLMNR
          "-p tcp -m tcp --dport 9092 -j ACCEPT" # Synapse metrics
        ];
      };

      services.matrix-synapse.enable = true;
      services.matrix-synapse.dataDir = "/var/lib/matrix-synapse";
      services.matrix-synapse.extraConfigFiles =
        [ fsec."services/matrix/config_secrets".path ];
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
        enable_metrics = true;
        max_upload_size = "100M";
        url_preview_enabled = true;
        report_stats = true;
        tls_certificate_path = fsec."services/matrix/tls_certificate".path;
        tls_private_key_path = fsec."services/matrix/tls_private_key".path;
        app_service_config_files = [
          fsec."services/matrix_appservice_discord/registration".path
        ];
        # Silence assertion, this is configured in `config_secrets`.
        database.args.host = "databases";
        database.args.name = "psycopg2";
        database.args.user = null;
        database.args.password = null;
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
      systemd.services.forward-v6-to-v4-for-metrics = {
        description = "Listen in ipv6 and forward to synapse metrics over ipv4";
        requiredBy = [ "matrix-synapse.service" ];
        after = [ "matrix-synapse.service" ];
        serviceConfig.ExecStart = ''
          ${pkgs.socat}/bin/socat -v \
            TCP6-LISTEN:9092,ipv6only,fork \
            TCP-CONNECT:localhost:9092'';
        serviceConfig.Type = "exec";
      };
      services.matrix-appservice-discord = {
        enable = true;
        settings = {
          bridge.domain = "orbstheorem.ch";
          bridge.homeserverUrl = "https://orbstheorem.ch";
          bridge.adminMxid = "@roosemberth:orbstheorem.ch";
          bridge.disableJoinLeaveNotifications = true;
          # database set via APPSERVICE_DISCORD_DATABASE_CONN_STRING envvar
          database.connString = null;
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
    forwardPorts = [{ hostPort = 8448; protocol = "tcp"; }];
  };

  roos.container-host.firewall.matrix = {
    in-rules = [
      # DNS
      "-p udp -m udp --dport 53 -j ACCEPT"
    ];
    ipv4.fwd-rules = [
      # Replies to the reverse proxy
      "-d 10.13.255.101/32 -m state --state RELATED,ESTABLISHED -j ACCEPT"
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
    "services/matrix/config_secrets" = secretCfg;
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
    chown ${o}:${g} "${fsec."services/matrix/config_secrets".path}"
    chown ${o}:${g} "${fsec."services/matrix_appservice_discord/registration".path}"
  '';
}
