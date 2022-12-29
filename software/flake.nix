{
  inputs = {
    # The 'nixpkgs' input is purposefully not specified here:
    # It is expected to use the lockfile (so, my machine) or provide your own
    # nixpkgs (from your registry). If this ever is used for more than one
    # person this may change.
  };

  outputs = { self, nixpkgs }: let
    lib = nixpkgs.lib;

    forAllSystems = fn: {
      "x86_64-linux" = fn (import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlays.default ];
      });
    };
  in {
    overlays.default = import ./overlay.nix;

    packages = forAllSystems
      (pkgs: (with lib; getAttrs (attrNames (self.overlays.default {} {})) pkgs));

    templates = import ./templates.nix;
  };
}
