{ config, lib, ... }:
let
  dotfilesHarness = { pkgs, ... }: {
    _module.args = {
      dotfileUtils = import ../modules/util.nix { inherit config pkgs lib; };
    };
  };
in {
  allModules = [
    ./test-module.nix
    ./email-gateway.nix
    ./vim-roos.nix
    ./sway-session.nix
    dotfilesHarness
  ];
}
