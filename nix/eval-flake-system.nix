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

    # Fix flake registry inputs of the target derivation
    ({ lib, ... }: {
      nixpkgs.overlays = lib.optional (self ? overlay) self.overlay;
      # Let 'nixos-version --json' know the Git revision of this flake.
      system.configurationRevision = lib.mkIf (self ? rev) self.rev;

      # Propagate all flake inputs into the registry.
      nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) (inputs // {
        # Alias nixpkgs to 'p'.
        p = inputs.nixpkgs;
      });

      environment.etc = nixpkgs.lib.mapAttrs' (name: flake: {
        name = "nix/system-evaluation-inputs/${name}";
        value.source = flake.outPath;
      }) inputs;

      nix.nixPath = [ "/etc/nix/system-evaluation-inputs" ];
    })
  ];
}
