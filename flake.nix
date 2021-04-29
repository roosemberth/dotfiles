{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.stable.url = "github:NixOS/nixpkgs/nixos-20.09";
  inputs.home-manager.url = "github:nix-community/home-manager";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = flakes@{ self, nixpkgs, home-manager, flake-utils, stable }: let
    defFlakeSystem = baseCfg: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [({ ... }: {
        _module.args.hmlib = home-manager.lib.hm;
        imports = [
          baseCfg
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules =
              (import ./nix/home-manager {}).allModules;
          }
        ];
        # Let 'nixos-version --json' know the Git revision of this flake.
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
        nix.registry.p.flake = nixpkgs;
        nix.registry.nixpkgs.flake = nixpkgs;
        nix.registry.stable.flake = stable;
      })];
    };
    forAllSystems = fn: nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems
      (system: fn (import nixpkgs { inherit system; }));
  in {
    nixosConfigurations = {
      Mimir = defFlakeSystem ./nix/machines/Mimir.nix;
      Minerva = defFlakeSystem ./nix/machines/Minerva.nix;
      batman = defFlakeSystem {
        _module.args.nixosSystem = nixpkgs.lib.nixosSystem;
        _module.args.home-manager = home-manager.nixosModules.home-manager;
        imports = [ ./nix/machines/tests/batman.nix ];
      };
    };
    apps = with nixpkgs.lib; (forAllSystems (pkgs: let
      toApp = name: drv: let host = removePrefix "vms/" name; in
        { type = "app"; program = "${drv}/bin/run-${host}-vm"; };
      isVm = name: _: hasPrefix "vms/" name;
      vmApps = mapAttrs toApp (filterAttrs isVm self.packages."${pkgs.system}");
    in vmApps));
    packages = (forAllSystems (pkgs: flake-utils.lib.flattenTree {
      vms = pkgs.lib.recurseIntoAttrs
        (import ./nix/machines/vms.nix { inherit flakes pkgs; });
    }));
    templates.generic.path = ./nix/flake-templates/generic;
    templates.generic.description = "Generic template for my projects.";
    defaultTemplate = self.templates.generic;
  };
}
