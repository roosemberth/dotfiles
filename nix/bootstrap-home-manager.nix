# This module provides the harness to home-manager
{ home-manager-flake }: { config, lib, ... }:
{
  _module.args.hmlib = home-manager-flake.lib.hm;
  imports = [ home-manager-flake.nixosModules.home-manager ];
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.sharedModules =
    (import ./home-manager { inherit config lib; }).allModules;
}
