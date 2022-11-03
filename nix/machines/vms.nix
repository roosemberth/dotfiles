system: dist: let
  lib = dist.nixpkgs.lib;
  mkVm = hostname: vmCfg: dist.nixpkgs.lib.makeOverridable
    # Allow overriding the system and distribution.
    ({ system, dist }: import ../eval-flake-system.nix system dist {
      imports = [
        ./tests/base.nix
        vmCfg
        {
          networking.hostName = hostname;
          services.sshd.enable = lib.mkDefault true;
          networking.firewall.enable = lib.mkDefault false;
        }
      ];
    })
    { inherit system dist; };
in {
  batman = mkVm "batman" {
    _module.args.nixosSystem = dist.nixpkgs.lib.nixosSystem;
    _module.args.home-manager = dist.hm.nixosModules.home-manager;
    imports = [ ./nix/machines/tests/batman.nix ];
  };

  foo = mkVm "foo" ({ pkgs, ... }: {
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
  });
}
