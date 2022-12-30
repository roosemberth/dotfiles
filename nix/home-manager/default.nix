{ config, lib, ... }:
let
  dotfilesHarness = { pkgs, ... }: {
    _module.args = {
      dotfileUtils = import ../modules/util.nix { inherit config pkgs lib; };
    };
  };
in {
  allModules = [
    ./actions.nix
    ./media.nix
    ./shells.nix
    ./reactimate-files.nix
    ./roos-sway-config.nix
    ./sway-session.nix
    ./wayland-session.nix
    ./swaync.nix
    ./test-module.nix
    ./vim-roos.nix
    dotfilesHarness
  ];
}
