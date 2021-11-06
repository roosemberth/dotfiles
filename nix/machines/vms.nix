{ pkgs, flakes, ... }:
let
  mkVmNoHm = hostname: baseConfig: (flakes.nixpkgs.lib.nixosSystem {
    system = pkgs.system;
    modules = [({ config, lib, ... }: {
      imports = [
        ./tests/base.nix
        baseConfig
      ];
      networking.hostName = hostname;
      services.sshd.enable = true;
      networking.firewall.enable = false;
    })];
  }).config.system.build.vm;

  mkVm = hostname: baseConfig: mkVmNoHm hostname {
    imports = [
      ../modules
      baseConfig
      (import ../bootstrap-home-manager.nix
        { home-manager-flake = flakes.home-manager; })
    ];
    nix.registry.nixpkgs.flake = flakes.nixpkgs;
  };
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
