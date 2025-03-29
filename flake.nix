{
  inputs = {
    # Vicuña
    vicuna-nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    vicuna-hm.url = "github:nix-community/home-manager/release-24.11";
    vicuna-hm.inputs.nixpkgs.follows = "vicuna-nixpkgs";
    vicuna-sops-nix.url = "github:Mic92/sops-nix";
    vicuna-sops-nix.inputs.nixpkgs.follows = "vicuna-nixpkgs";

    # Unstable
    unstable-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    unstable-hm.url = "github:nix-community/home-manager";
    unstable-hm.inputs.nixpkgs.follows = "unstable-nixpkgs";
    unstable-sops-nix.url = "github:Mic92/sops-nix";
    unstable-sops-nix.inputs.nixpkgs.follows = "unstable-nixpkgs";
    unstable-nur.url = "github:nix-community/NUR";
    unstable-cosmic.url = "github:lilyinstarlight/nixos-cosmic";
    unstable-cosmic.inputs.nixpkgs.follows = "unstable-nixpkgs";

    # Agnostic
    flake-utils.url = "github:numtide/flake-utils";
    flake-registry.url = "github:NixOS/flake-registry";
    flake-registry.flake = false;
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = inputs@{ self, flake-utils, nixos-hardware, ... }: let
    # Distributions
    vicuna = with inputs; {
      inherit (inputs) self flake-utils flake-registry;
      nixpkgs = vicuna-nixpkgs;
      hm = vicuna-hm;
      sops-nix = vicuna-sops-nix;
    };
    unstable = with inputs; {
      inherit (inputs) self flake-utils flake-registry;
      nixpkgs = unstable-nixpkgs;
      hm = unstable-hm;
      sops-nix = unstable-sops-nix;
      nur = unstable-nur;
      cosmic = unstable-cosmic;
    };

    lib = unstable.nixpkgs.lib;

    mkSystem = dist: cfg:
      import ./nix/eval-flake-system.nix "x86_64-linux" dist cfg;

    forAllSystems = { self, nixpkgs, flake-utils, ... }: fn:
      lib.genAttrs flake-utils.lib.defaultSystems
        (s: fn (import nixpkgs { system = s; overlays = [ self.overlay ]; }));

    hosts = {
      janus = mkSystem unstable ({ ... }: {
        imports = [
          ./nix/machines/Janus.nix
          nixos-hardware.nixosModules.framework-13-7040-amd
        ];
      });
      Mimir = mkSystem unstable ./nix/machines/Mimir.nix;
      Minerva = mkSystem vicuna ./nix/machines/Minerva.nix;
      Heimdaalr = mkSystem vicuna ./nix/machines/Heimdaalr.nix;
      strong-ghost = import ./nix/eval-flake-system.nix "aarch64-linux"
        unstable ./nix/machines/strong-ghost.nix;
    };
  in {
    nixosConfigurations = {
      inherit (hosts) Mimir Mimir-vm Minerva Heimdaalr janus strong-ghost;
    };

    apps = with lib; forAllSystems unstable (pkgs: with lib; let
      toApp = name: drv:
        { type = "app"; program = "${drv}/bin/run-${name}-vm"; };
      nixosConfigApps = mapAttrs
        (name: _: toApp name self.packages."${pkgs.system}"."${name}") hosts;
    in nixosConfigApps);

    overlay = import ./software/overlay.nix;

    templates = import ./software/templates.nix;

    packages = forAllSystems unstable (pkgs: with lib; let
      overlayPackages = getAttrs (attrNames (self.overlay {} {})) pkgs;
      nixosConfigPackages = mapAttrs (_: c: c.config.system.build.vm) hosts;
    in nixosConfigPackages // overlayPackages);

    devShells = forAllSystems unstable
      (pkgs: import ./nix/dev-shells.nix { inherit pkgs; });
  };
}
