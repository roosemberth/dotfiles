{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.home-manager.url = "github:nix-community/home-manager/release-21.05";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = flakes@{ self, nixpkgs, home-manager, flake-utils }:
  let
    defFlakeSystem = baseCfg: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [({ ... }: {
        imports = [
          baseCfg
          (import ./nix/bootstrap-home-manager.nix
            { home-manager-flake = home-manager; })
        ];
        nixpkgs.overlays = [ self.overlay ];
        # Let 'nixos-version --json' know the Git revision of this flake.
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
        nix.registry.p.flake = nixpkgs;
        nix.registry.nixpkgs.flake = nixpkgs;
      })];
    };
    forAllSystems = fn: nixpkgs.lib.genAttrs flake-utils.lib.defaultSystems
      (sys: fn (import nixpkgs { system = sys; overlays = [ self.overlay ]; }));
  in {
    nixosConfigurations = {
      Mimir = defFlakeSystem ./nix/machines/Mimir.nix;
      Mimir-vm = defFlakeSystem ({ modulesPath, ... }: {
        imports = [ ./nix/machines/Mimir.nix ./nix/modules/vm-compat.nix ];
      });
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

    overlay = import ./nix/pkgs/overlay.nix;

    packages = (forAllSystems (pkgs: flake-utils.lib.flattenTree {
      vms = pkgs.lib.recurseIntoAttrs
        (import ./nix/machines/vms.nix { inherit flakes pkgs; });
    } // (with nixpkgs.lib; getAttrs (attrNames (self.overlay {} {})) pkgs)));

    templates.generic.path = ./nix/flake-templates/generic;
    templates.generic.description = "Generic template for my projects.";
    defaultTemplate = self.templates.generic;
  };
}
