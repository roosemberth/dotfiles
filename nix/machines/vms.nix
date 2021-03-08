{ pkgs, flakes, ... }:
let
  mkVm = hostname: configuration: (flakes.nixpkgs.lib.nixosSystem {
    system = pkgs.system;
    modules = [({ ... }: {
      _module.args.hmlib = flakes.home-manager.lib.hm;
      imports = [
        ./tests/base.nix
        flakes.home-manager.nixosModules.home-manager
        ../modules
        configuration
      ];
      networking.hostName = hostname;
      services.sshd.enable = true;
      networking.firewall.enable = false;
      home-manager.sharedModules = (import ../home-manager {}).allModules;
    })];
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
}
