{ config, ... }:
{
  config.nixpkgs.overlays = [ (import ../pkgs/overlay.nix) ];
}
