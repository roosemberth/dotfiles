{ pkgs, dist, ... }:
let
  mkVm = hostname: cfg: (import ../eval-flake-system.nix pkgs.system dist {
    imports = [
      ./tests/base.nix
      cfg
      {
        networking.hostName = hostname;
        services.sshd.enable = true;
        networking.firewall.enable = false;
      }
    ];
  }).config.system.build.vm;
in {
  foo = mkVm "foo" {
    systemd.services.enable-roos-linger = {
      after = [ "systemd-logind.service" ];
      bindsTo = [ "systemd-logind.service" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/loginctl enable-linger roos";
      };
    };
    home-manager.users.roos.home.stateVersion = "20.09";
    home-manager.users.roos.systemd.user.startServices = true;
    home-manager.users.roos.programs.test-service.enable = true;
  };
  powerflow-test-vm = mkVm "powerflow-test-vm" {
    imports = [ ./containers/powerflow.nix ];
    networking.nat.enable = true;
    networking.nat.externalInterface = "eth0";
    virtualisation.memorySize = 1024;
  };
}
