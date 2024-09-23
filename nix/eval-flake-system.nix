system: inputs@{ nixpkgs, hm, sops-nix, self, ... }:
let
  lib = nixpkgs.lib;
in systemConfiguration: nixpkgs.lib.nixosSystem {
  inherit system;

  modules = [
    systemConfiguration

    # Custom modules
    ({ ... }: {
      _module.args = {
        networks.zkx = rec {
          dns = let
            removeCIDR = with lib; str: head (splitString "/" str);
          in {
            v4 = removeCIDR publicInternalAddresses.Minerva.v4;
            v6 = removeCIDR publicInternalAddresses.Minerva.v6;
          };
          publicInternalAddresses = {
            Heimdaalr.v4 = "10.13.255.101/24";
            Heimdaalr.v6 = "fd00:726f:6f73:101::1/56";
            Mimir.v4 = "10.13.255.35/24";
            Mimir.v6 = "fd00:726f:6f73:35::1/56";
            Minerva.v4 = "10.13.255.13/24";
            Minerva.v6 = "fd00:726f:6f73:13::1/56";
          };
        };
        users.roos = {
          ssh-public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSKHqDX+M61dKgmFJL1dlJQTvveSkcG99GWb3R2P5Tq argon2d-cbc-spf";
          hashedPassword = "$gy$j9T$zbhaIklVZtEL60nhD3phG1$enEdsSN2V831HzgdG8tWk.CCyRf2GEABXz7e0YM/4/4";
        };
      };
      imports = [
        ./modules/agenda.nix
        ./modules/backups.nix
        ./modules/base.nix
        ./modules/btrbk.nix
        ./modules/container-host.nix
        ./modules/dev.nix
        ./modules/firewall.nix
        ./modules/layout-trees.nix
        ./modules/lib.nix
        ./modules/media.nix
        ./modules/nginx-fileshare.nix
        ./modules/steam.nix
        ./modules/unfree.nix
        ./modules/user-profiles/roosemberth.nix
        ./modules/users.nix
        ./modules/wireguard-new.nix
        ./modules/wireguard.nix
      ] ++ (lib.optionals (lib.versionAtLeast lib.version "24.11") [
        ./modules/hyprland-session.nix
        ./modules/sway-session.nix
        ./modules/wayland-session.nix
      ]);
    })

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
      environment.extraInit = ''
        if [ -d "/etc/profiles/per-user/$USER/etc/profile.d" ]; then
          . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
        fi
      '';
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
      nixpkgs.overlays = ifFound "nur";
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
