{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.home-manager.url =
    "github:nix-community/home-manager/release-20.09";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, home-manager }: {
    nixosConfigurations = {
      batman = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [({ ... }: {
          _module.args.nixosSystem = nixpkgs.lib.nixosSystem;
          imports = [ ./nix/machines/tests/batman.nix ];
        })];
      };
      Mimir = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [({ ... }: {
          imports = [
            ./nix/machines/Mimir.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
            }
          ];
          # Let 'nixos-version --json' know the Git revision of this flake.
          system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
          nix.registry.nixpkgs.flake = nixpkgs;
        })];
      };
    };
  };
}
