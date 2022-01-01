{ config, pkgs, lib, secrets, containerHostConfig, ... }: let
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
in {
  containers.monitoring = {
    autoStart = true;
    bindMounts.prometheus.hostPath = "/mnt/cabinet/minerva-data/prometheus2";
    bindMounts.prometheus.mountPoint = "/var/lib/prometheus2";
    bindMounts.prometheus.isReadOnly = false;
    config = {
      networking.firewall.allowedTCPPorts = [ 9090 9093 ];
      networking.interfaces.eth0.ipv4.routes = [
        { address = "0.0.0.0"; prefixLength = 0; via = "10.231.136.1"; }
      ];
      networking.nameservers = containerHostConfig.nameservers;
      networking.search = with secrets.network.zksDNS; [ search ];
      networking.useHostResolvConf = false;
      nix.package = pkgs.nixUnstable;
      nix.extraOptions = "experimental-features = nix-command flakes";

      services.prometheus = {
        enable = true;
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
        }];
        alertmanagers = [{ static_configs = [{ targets = [ "localhost:9093" ]; }]; }];
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
            { name = "default-receiver"; }
            {
              name = "sms"; webhook_configs = [{
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
      };
    };
    ephemeral = true;
    # Port forwarding only works on ipv4...
    localAddress = "10.231.136.6/24";
    hostBridge = "containers";
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
}
