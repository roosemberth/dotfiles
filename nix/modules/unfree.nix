# This module is a workaround to option allowUnfreePredicate, since the current
# functor instance does not merge the predicates but rather picks one at random.
{ config, lib, ... }: with lib;
let
  allowedList = []
    ++ optionals config.roos.steam.enable
      ["steam" "steam-unwrapped" "steam-runtime" "steam-run"]
    ++ ["ninja-cookie" "mpv-youtube-quality" "castlabs-electron" ]
    ;
in {
  config.nixpkgs.config.allowUnfreePredicate =
    pkg: elem (getName pkg) allowedList;
}
