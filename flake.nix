{
  inputs.nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-21.05";
  inputs.nixpkgs-porcupine.url = "github:NixOS/nixpkgs/nixos-21.11";
  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs";
  inputs.hm-stable.url = "github:nix-community/home-manager/release-21.05";
  inputs.hm-stable.inputs.nixpkgs.follows = "nixpkgs-stable";
  inputs.hm-porcupine.url = "github:nix-community/home-manager/release-21.11";
  inputs.hm-porcupine.inputs.nixpkgs.follows = "nixpkgs-porcupine";
  inputs.hm-unstable.url = "github:nix-community/home-manager";
  inputs.hm-unstable.inputs.nixpkgs.follows = "nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = flakes@{
    self,
    nixpkgs-unstable,
    nixpkgs-porcupine,
    nixpkgs-stable,
    hm-stable,
    hm-porcupine,
    hm-unstable,
    flake-utils,
  }:
  let
    defFlakeSystem = {
      nixpkgs ? nixpkgs-stable,
      home-manager ? hm-stable,
    }: baseCfg: nixpkgs.lib.nixosSystem {
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
    forAllSystems = { nixpkgs ? nixpkgs-unstable }: fn:
      nixpkgs.lib.genAttrs
        flake-utils.lib.defaultSystems
        (sys: fn (import nixpkgs
          { system = sys; overlays = [ self.overlay ]; }));
  in {
    nixosConfigurations = {
      Mimir = defFlakeSystem {
        nixpkgs = nixpkgs-unstable;
        home-manager = hm-unstable;
      } ./nix/machines/Mimir.nix;
      Mimir-vm = defFlakeSystem {} ({ modulesPath, ... }: {
        imports = [ ./nix/machines/Mimir.nix ./nix/modules/vm-compat.nix ];
      });
      Minerva = defFlakeSystem {} ./nix/machines/Minerva.nix;
      Heimdaalr = defFlakeSystem {
        nixpkgs = nixpkgs-porcupine;
        home-manager = hm-porcupine;
      } ./nix/machines/Heimdaalr.nix;
      batman = defFlakeSystem {} {
        _module.args.nixosSystem = nixpkgs-stable.lib.nixosSystem;
        _module.args.home-manager = hm-stable.nixosModules.home-manager;
        imports = [ ./nix/machines/tests/batman.nix ];
      };
    };
    apps = with nixpkgs-unstable.lib; (forAllSystems {} (pkgs: let
      toApp = name: drv: let host = removePrefix "vms/" name; in
        { type = "app"; program = "${drv}/bin/run-${host}-vm"; };
      isVm = name: _: hasPrefix "vms/" name;
      vmApps = mapAttrs toApp (filterAttrs isVm self.packages."${pkgs.system}");
    in vmApps));

    overlay = import ./nix/pkgs/overlay.nix;

    packages = (forAllSystems {} (pkgs: flake-utils.lib.flattenTree {
      vms = pkgs.lib.recurseIntoAttrs
      (import ./nix/machines/vms.nix {
        inherit pkgs;
        flakes = flakes // {
          nixpkgs = nixpkgs-unstable;
          home-manager = hm-unstable;
        };
      });
      } // (with nixpkgs-unstable.lib; getAttrs
              (attrNames (self.overlay {} {})) pkgs)));

    templates.generic.path = ./nix/flake-templates/generic;
    templates.generic.description = "Generic template for my projects.";
    defaultTemplate = self.templates.generic;
    devShells = forAllSystems { nixpkgs = nixpkgs-stable; }
      (pkgs: import ./nix/dev-shells.nix { inherit pkgs; });
  };
}
