{ pkgs, flakes, ... }:
let
  mkVm = hostname: configuration: (flakes.nixpkgs.lib.nixosSystem {
    system = pkgs.system;
    modules = [({ ... }: {
      imports = [
        ./tests/base.nix
        flakes.home-manager.nixosModules.home-manager
        ../modules
        configuration
      ];
      networking.hostName = hostname;
      services.sshd.enable = true;
      networking.firewall.enable = false;
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
    home-manager.users.roos.systemd.user.services.foo-test = {
      Service.ExecStart = let
        script = pkgs.writeShellScript "foo-test"
        "echo 'User process ran' | ${pkgs.systemd}/bin/systemd-cat";
      in "${script}";
      Service.RemainAfterExit = true;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
