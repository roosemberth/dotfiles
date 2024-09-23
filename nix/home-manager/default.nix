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
    ./swaync.nix
    ./test-module.nix
    ./vim-roos.nix
    dotfilesHarness
  ] ++ (lib.optionals (lib.versionAtLeast lib.version "24.11") [
    ./roos-sway-config.nix
    ./hyprland-session.nix
    ./sway-session.nix
    ./wayland-session.nix
  ]);
}
