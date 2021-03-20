{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-20.09";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "i686-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs {
      inherit system; overlays = [ self.overlay ];
    }));
  in {
    overlay = final: prev: with final; {
      # pkgs go here :D
    };

    devShell = forAllSystems (pkgs: with pkgs; stdenv.mkDerivation {
      name = "devshell";
      nativeBuildInputs = [];
      preferLocalBuild = true;
      allowSubstitutes = false;
    });

    # Export all packages from the overlay attribute.
    packages = forAllSystems (pkgs: with pkgs.lib;
      getAttrs (attrNames (self.overlay {} {})) pkgs
    );
  };
}
