{
  # By default, use the 'nixpkgs' flake from the host registry.
  # Uncomment to pin a nixpkgs release to this project.
  # inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "i686-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
      inherit system; overlays = [ self.overlay ];
    }));
  in {
    overlay = final: prev: with final; {
      # Don't forget to rename this!
      myrustpackage = rustPlatform.buildRustPackage {
        pname = "myrustpackage";
        version = "0.0.0";
        src = ./.;

        nativeBuildInputs = [ pkgconfig ];
        buildInputs = [ ];

        cargoLock = {
          lockFile = ./Cargo.lock;
        };
      };
    };

    devShells = forAllSystems (pkgs: with pkgs; {
      default = mkShell {
        packages = [ cargo clippy gdb rust-analyzer rustc rustfmt ];
        inputsFrom = [ myrustpackage ];
      };
    });

    # Export all packages from the overlay attribute.
    packages = forAllSystems (pkgs: with pkgs.lib;
      getAttrs (attrNames (self.overlay {} {})) pkgs
    );
  };
}
