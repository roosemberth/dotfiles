# Inspired from Infinisil's configuration repository @df9232c4 and my own
# modules systems prior to @02723409fb50dc52df92849383fa0c6a3572f987
{ lib, ... }: with lib;
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
  # - Are util.nix (bottom)
  # This also makes the strings absolute.
  validFiles = dir: map (file: ./. + "/${file}")
    (filter (file: hasSuffix ".nix" file
                && file != "default.nix"
                && file != "util.nix")
    (files dir));
in {
  _module.args = {
    secrets = import ../secrets.nix { inherit lib; _modinjector = true; };
  };
  imports = validFiles ./.;
}
