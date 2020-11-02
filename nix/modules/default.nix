# Inspired from Infinisil's configuration repository @df9232c4 and my own
# modules systems prior to @02723409fb50dc52df92849383fa0c6a3572f987
{ lib, ... }: with lib;
let
  hm =
    let try = builtins.tryEval <home-manager>;
    in if try.success then try.value
    else builtins.trace "Using pinned version for home manager" (
      builtins.fetchGit {
        url = "https://github.com/rycee/home-manager.git";
        rev = "dd93c300bbd951776e546fdc251274cc8a184844";
      });
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
  sourceHmEnv = {
    # Source home-manager environment
    config.environment.extraInit = ''
      if [ -d "$HOME/.nix-profile/etc/profile.d" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };
in {
  _module.args = {
    hmlib = import (hm + "/modules/lib") { inherit lib; };
    secrets = import ../secrets.nix { inherit lib; _modinjector = true; };
  };
  imports = [ (hm + "/nixos") sourceHmEnv ] ++ validFiles ./.;
}
