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
    virtualisation.enableGraphics = true;
  };
}
