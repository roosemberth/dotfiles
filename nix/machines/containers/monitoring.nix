{ config, pkgs, lib, secrets, ... }: let
  fsec = config.sops.secrets;
  send-monitoring-sms-alert = with secrets.monitoring.alert-routes.twilio;
    pkgs.writeShellScript "send-monitoring-sms-alert" ''
      MSG="$(${pkgs.jq}/bin/jq -r '.alerts[]|.annotations.description' "$BODY")"
      if [ -z "$MSG" ]; then
        echo "Failed to decode notification..." >&2
        ${pkgs.jq}/bin/jq . "$BODY" >&2
        MSG="The monitoring system generated an alarm."
      fi
      exec ${pkgs.httpie}/bin/https --ignore-stdin --check-status \
        --pretty=format -a '${auth}' --form '${url}' \
        MessagingServiceSid='${mss}' To='${dest}' Body="$MSG"
    '';
  hooksF = pkgs.writeText "alertmanager.yml" (builtins.toJSON [
    { id = "monitoring-sms-notification";
      http-methods = ["POST"];
      pass-file-to-command =
        [{ source = "entire-payload"; envname = "BODY"; }];
      execute-command = send-monitoring-sms-alert;
    }
  ]);
  matrix-amconfig = (pkgs.formats.toml {}).generate "matrix-amconfig.toml" {
    inherit (secrets.monitoring.alert-routes.matrix) TargetRoomID MXID MXToken;
    Homeserver = "https://orbstheorem.ch";
    HTTPPort = 9096;
    HTTPAddress = "[::1]";
  };
in {
  containers.monitoring = {
    autoStart = true;
    bindMounts.monitoring-prometheus.hostPath =
      config.roos.container-host.guestMounts.monitoring-prometheus.hostPath;
    bindMounts.monitoring-prometheus.mountPoint = "/var/lib/prometheus2";
    bindMounts.monitoring-prometheus.isReadOnly = false;
    bindMounts."/run/secrets/services/monitoring" = {};
    config = {
      networking.firewall.allowedTCPPorts = [ 9090 9093 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = config.roos.container-host.nameservers;
      networking.search = with secrets.network.zksDNS; [ search ];
      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";
      nixpkgs.config.permittedInsecurePackages = [
        "prometheus-nextcloud-exporter-0.4.0" # CVE-2022-21698 does not affect me
      ];
      services.prometheus = {
        enable = true;
        exporters.smokeping = {
          enable = true;
          hosts = [
            "Heimdaalr.orbstheorem.ch"
            secrets.network.zkx.Heimdaalr.ep.addr
            "ipv6.google.com"
            "ipv4.google.com"
          ];
        };
        exporters.nextcloud = {
          enable = true;
          url = "https://nextcloud.orbstheorem.ch";
          username = secrets.monitoring.exporter.nextcloud_user;
          passwordFile = fsec."services/monitoring/exporter/nextcloud_pass".path;
        };
        webExternalUrl = "https://monitoring.orbstheorem.ch/";
        ruleFiles = [
          ./prometheus/synapse-v2.rules  # Rules for matrix-synapse
          ./prometheus/alerts.rules
        ];
        scrapeConfigs = [{
          job_name = "synapse";
          metrics_path = "/_synapse/metrics";
          # For some reason, the "official" synapse Grafana chart requires 15s?
          scrape_interval = "15s";
          static_configs = [{ targets = [
            "minerva.intranet.orbstheorem.ch:9092"
          ];}];
        } {
          job_name = "node";
          static_configs = [{ targets = [
            "minerva.intranet.orbstheorem.ch:9100"
            "heimdaalr.intranet.orbstheorem.ch:9100"
          ];}];
        } {
          job_name = "postgres";
          static_configs = [{ targets = [
            "minerva.intranet.orbstheorem.ch:9187"
          ];}];
        } {
          job_name = "nextcloud";
          static_configs = let
            port = config.services.prometheus.exporters.nextcloud.port;
          in [{ targets = [ "localhost:${toString port}" ]; }];
        } {
          job_name = "smokeping";
          honor_labels = true;
          static_configs = let
            port = config.services.prometheus.exporters.smokeping.port;
          in [{ targets = [ "localhost:${toString port}" ]; }];
        } {
          job_name = "bind";
          static_configs = let
            port = toString config.services.prometheus.exporters.bind.port;
          in [{ targets = [
            "minerva.intranet.orbstheorem.ch:${port}"
            "heimdaalr.intranet.orbstheorem.ch:${port}"
          ];}];
        }];
        alertmanagers = [{ static_configs = [{ targets = [ "[::1]:9093" ]; }]; }];
        alertmanager.enable = true;
        alertmanager.configuration = {
          route = {
            receiver = "default-receiver";
            group_wait = "1m";
            repeat_interval = "12h";
            group_by = [ "severity" ];
            routes = [
              { receiver = "sms"; match.severity = "critical"; }
            ];
          };
          receivers = [
            { name = "default-receiver";
              webhook_configs = [{ url = "http://localhost:9096/alert"; }];
            }
            { name = "sms"; webhook_configs = [{
                send_resolved = false;
                url = "http://localhost:9095/hooks/monitoring-sms-notification";
              }];
            }
          ];
        };
        alertmanager.webExternalUrl = "https://alerts.orbstheorem.ch/";
      };

      systemd.services."alertmanager-webhookd" = {
        description = "webhooks server for alertmanager actions";
        requiredBy = ["alertmanager.service"];
        partOf = ["alertmanager.service"];
        before = ["alertmanager.service"];
        serviceConfig.ExecStart = let
          webhook = "${pkgs.webhook}/bin/webhook";
        in "${webhook} -verbose -ip 127.0.0.1 -port 9095 -hooks ${hooksF}";
        serviceConfig.Restart = "always";
        serviceConfig.RestartSec = 3;
      };

      systemd.services."matrix-alertmanager-receiver" = {
        description = "webhooks server relaying alertmanager actions to matrix";
        requiredBy = ["alertmanager.service"];
        partOf = ["alertmanager.service"];
        before = ["alertmanager.service"];
        serviceConfig.ExecStart = let
          pkg = pkgs.matrix-alertmanager-receiver;
        in "${pkg}/bin/matrix-alertmanager-receiver -config ${matrix-amconfig}";
        serviceConfig.Restart = "always";
        serviceConfig.RestartSec = 3;
      };
      # Need fixed ids to set secret permissions on host activation script
      users.users.nextcloud-exporter.uid = 998;
      users.groups.nextcloud-exporter.gid = 998;
      system.stateVersion = "22.05";
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.6/24";
    hostBridge = "orion";
    privateNetwork = true;
    forwardPorts = [
      { hostPort = 9090; protocol = "tcp"; }
      { hostPort = 9093; protocol = "tcp"; }
    ];
  };

  roos.container-host.firewall.monitoring = {
    in-rules = [
      "-p udp -m udp --dport 53 -j ACCEPT"
      "-j ACCEPT"  # Monitoring can access the host.
    ];
    ipv4.fwd-rules = [ "-j ACCEPT" ];
  };
  roos.container-host.guestMounts.monitoring-prometheus = {};

  # We cannot set the required owner and group since the target values don't
  # exist in the host configuration, thus failing the activation script.
  sops.secrets."services/monitoring/exporter/nextcloud_pass".restartUnits =
    [ "container@monitoring.service" ];

  system.activationScripts.secretsForMonitoring = let
    cfg = config.containers.monitoring.config;
    o = toString cfg.users.users.nextcloud-exporter.uid;
    g = toString cfg.users.groups.nextcloud-exporter.gid;
  in lib.stringAfter ["setupSecrets"] ''
    chown ${o}:${g} "${fsec."services/monitoring/exporter/nextcloud_pass".path}"
  '';
}
