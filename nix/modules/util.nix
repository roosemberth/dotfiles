{ config, pkgs, lib, ...}:
{
  fetchDotfile = target: let
    impure = config.roos.impureDotfiles;
    dotfiles = assert config.roos.dotfilesPath != null; config.roos.dotfilesPath;
  in pkgs.runCommandNoCCLocal "${if impure then "impure-" else ""}dotfile-path" {} ''
    ln -s "${if impure then builtins.toString dotfiles else dotfiles}/${target}" "$out"
  '';
}
