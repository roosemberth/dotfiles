{ config, pkgs, secrets, containerHostConfig, ... }: {
  containers.matrix = {
    autoStart = true;
    bindMounts.synapse-data.hostPath = "/mnt/cabinet/minerva-data/matrix-synapse";
    bindMounts.synapse-data.mountPoint = "/var/lib/matrix-synapse";
    bindMounts.synapse-data.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 8448 9092 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = containerHostConfig.nameservers;
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      services.matrix-synapse = {
        enable = true;
        server_name = "orbstheorem.ch";
        dataDir = "/var/lib/matrix-synapse";
        servers = {
          "pacien.net"."ed25519:a_fhhB" =
            "N8ZVXJG7CSnCK1+rthEmvoDo1tPlQC5bxcJuPA+/RZs";
          "gnugen.ch"."ed25519:a_bPqV" =
            "1NrywDVt85bq5qLeInMXgUY+Y7f7Lqza6XGpV5viPpU";
          "matrix.org"."ed25519:auto" =
            "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
        };
        listeners = [{
          port = 8448;
          resources = [{ names = [ "client" "federation" ]; compress = true; }];
          tls = false;
          x_forwarded = true;
        } {
          port = 9092;
          type = "metrics";
          resources = [];
          tls = false;
        }];
        enable_metrics = true;
        max_upload_size = "100M";
        url_preview_enabled = true;
        report_stats = true;
        inherit (secrets.matrix)
          turn_uris
          turn_shared_secret
          tls_dh_params_path
          tls_certificate_path
          tls_private_key_path
          database_type
          database_args
          ;
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.4/24";
    hostBridge = "containers";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 8448; protocol = "tcp"; }
      { hostPort = 9092; protocol = "tcp"; }
    ];
  };

  networking.firewall.extraCommands = let
    exitIface = config.networking.nat.externalInterface;
  in ''
    # Restrict access to hypervisor network
    iptables -A INPUT -s 10.231.136.4/32 -d 10.13.255.13/32 \
      -p tcp -m tcp --dport 5432 -j ACCEPT
    iptables -A INPUT -s 10.231.136.4/32 -j LOG \
      --log-prefix "dropped restricted connection" --log-level 6
    iptables -A INPUT -s 10.231.136.4/32 \
      -m state --state RELATED,ESTABLISHED -p tcp --sport 9092 -j ACCEPT
    iptables -A INPUT -s 10.231.136.4/32 -j DROP
    # Allow access to the database
    iptables -A FORWARD -s 10.231.136.4/32 -d 10.13.255.101/32 -j ACCEPT
    # Allow replies from the metrics port
    iptables -A FORWARD -s 10.231.136.4/32 -d 10.13.0.0/16 \
      -m state --state RELATED,ESTABLISHED -p tcp --sport 9092 -j ACCEPT
    iptables -A FORWARD -s 10.231.136.4/32 -d 10.231.136.0/24 \
      -m state --state RELATED,ESTABLISHED -p tcp --sport 9092 -j ACCEPT
    iptables -A FORWARD -s 10.231.136.4/32 -o ${exitIface} -j ACCEPT
    iptables -A FORWARD -s 10.231.136.4/32 -j LOG \
      --log-prefix "dropped restricted fwd connection" --log-level 6
    iptables -A FORWARD -s 10.231.136.4/32 -j DROP
  '';
}
