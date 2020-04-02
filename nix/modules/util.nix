{ config, pkgs, lib, ...}:
{
  fetchDotfile = target: let
    impure = config.roos.impureDotfiles;
    src = "${config.roos.dotfilesPath}/${target}";
  in if ! impure then pkgs.copyPathToStore src else
    pkgs.runCommandNoCCLocal "impure-dotfile-path" {} ''ln -s "${src}" "$out"'';
}
