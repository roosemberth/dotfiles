{ config, pkgs, lib, ...}: with builtins;
let
  dotfiles = assert config.roos.dotfilesPath != null; config.roos.dotfilesPath;
in {
  fetchDotfile = target: let
    impure = config.roos.impureDotfiles;
    name = "${if impure then "impure-" else ""}dotfile-path";
  in pkgs.runCommandNoCCLocal name {} ''
    ln -s "${if impure then toString dotfiles else dotfiles}/${target}" "$out"
  '';

  /* Replaces every occurrence of @varName@ in a copy of every file in path,
   * where varName is any variable in the specified attr set. If path is a file
   * only that file will be copied and processed.
   * The variable @destDir@ will be automatically added with value equal to the
   * derivation path.
   * Variables may start with lowercase and contain only alphabetic characters.
   */
  renderDotfile = path: attrs: let
    dotfile = pkgs.copyPathToStore "${toString dotfiles}/${path}";
  in pkgs.runCommand "rendered-dotfile-path" ({
    destDir = placeholder "out";
  } // attrs) ''
    cp -r "${dotfile}" $out
    find "$out" -type f | while read -r file; do
       substituteAllInPlace "$file"
    done
  '';
}
