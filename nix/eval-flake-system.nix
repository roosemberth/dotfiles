system: inputs@{ nixpkgs, hm, sops-nix, self, ... }:
systemConfiguration: nixpkgs.lib.nixosSystem {
  inherit system;

  modules = [
    systemConfiguration

    ./modules

    # Bootstrap sops
    ({ config, ... }: {
      imports = [ sops-nix.nixosModules.sops ];
      sops.defaultSopsFile =
        ../secrets/per-host + "/${config.networking.hostName}.yaml";
    })

    # Bootstrap home-manager
    ({ config, ... }: {
      _module.args.hmlib = hm.lib.hm;
      imports = [ hm.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.sharedModules =
        (import ./home-manager {
          inherit config;
          inherit (nixpkgs) lib;
        }).allModules;
    })

    # Bootstrap optional overlays
    ({ lib, ... }: with lib; let
      ifFound = attr: optional (hasAttr attr inputs) inputs."${attr}".overlay;
    in {
      nixpkgs.overlays = ifFound "nur" ++ ifFound "deploy-rs";
    })

    # Fix flake registry inputs of the target derivation
    ({ config, options, pkgs, lib, ... }: {
      nixpkgs.overlays = lib.optional (self ? overlay) self.overlay;
      # Let 'nixos-version --json' know the Git revision of this flake.
      system.configurationRevision = lib.mkIf (self ? rev) self.rev;

      # Propagate all flake inputs into the registry.
      nix.registry = (lib.mapAttrs (_: flake: { inherit flake; }) (inputs // {
        # Alias nixpkgs to 'p'.
        p = inputs.nixpkgs;
      })) // {
        tip.to = {
          owner = "NixOS";
          repo = "nixpkgs";
          type = "github";
        };
      };
      nix.settings.flake-registry =
        lib.mkDefault (inputs.flake-registry + "/flake-registry.json");

      environment.etc = nixpkgs.lib.mapAttrs' (name: flake: {
        name = "nix/system-evaluation-inputs/${name}";
        value.source = flake.outPath;
      }) inputs;

      nix.nixPath = [ "/etc/nix/system-evaluation-inputs" ];
    })
  ];
}
