# Inspired from Infinisil's configuration repository @df9232c4

{ lib, ... }:

with lib;

let
  # Recursively construct an attrset of a given path, recursing on directories.
  # The value of attrs is the filetype.
  getDir = dir: mapAttrs (file: type:
    if type == "directory" then getDir "${dir}/${file}" else type
  ) (builtins.readDir dir);

  # Collects all files of a directory as a list of strings of paths.
  files = dir: collect isString
    (mapAttrsRecursive (path: type: concatStringsSep "/" path) (getDir dir));

  # Filters out paths that:
  # - Don't end with .nix
  # - Are this file
  # - Are inside an `assets` directory
  # This also makes the strings absolute.
  validFiles = dir: map (file: ./. + "/${file}")
    (filter (file: hasSuffix ".nix" file
                && file != "default.nix"
                && ! hasPrefix "assets/" file)
    (files dir));

in

{
  imports = validFiles ./.;
}
