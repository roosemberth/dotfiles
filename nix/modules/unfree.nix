# This module is a workaround to option allowUnfreePredicate, since the current
# functor instance does not merge the predicates but rather picks one at random.
{ config, lib, ... }: with lib;
let
  allowedList = []
    ++ optionals config.roos.media.enable ["libspotify" "pyspotify"]
    ++ optionals config.roos.steam.enable ["steam-original" "steam" "steam-runtime"]
    ++ ["ninja-cookie" "mpv-youtube-quality"]
    ;
in {
  config.nixpkgs.config.allowUnfreePredicate =
    pkg: elem (getName pkg) allowedList;
}
