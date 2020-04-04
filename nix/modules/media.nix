{ config, pkgs, lib, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
  mopidy' = with pkgs; buildEnv {
    name = "mopidy-with-extensions-${mopidy.version}";
    paths = lib.closePropagation (with pkgs; [
      mopidy-spotify mopidy-iris mopidy-mpd
    ]);
    pathsToLink = [ "/${python3.sitePackages}" ];
    buildInputs = [ makeWrapper ];
    postBuild = ''
      makeWrapper ${mopidy}/bin/mopidy $out/bin/mopidy \
      --prefix PYTHONPATH : $out/${python3.sitePackages}
    '';
  };
in
{
  options.roos.media.enable = mkEnableOption "Enable media suite.";

  config = mkIf config.roos.media.enable {
    nixpkgs.config.allowUnfreePredicate =
      pkg: elem (getName pkg) ["libspotify" "pyspotify"
        "steam-original" # FIXME: See steam.nix
        ];

    roos.gConfig = {
      home.packages = with pkgs; [mpv youtube-dl mopidy'];
      xdg.configFile."mopidy/mopidy.conf".source =
        util.fetchDotfile "etc/mopidy/mopidy.conf";
      xdg.dataFile."mopidy/Playlists/.keep".text = "";  # Placeholder
    };
  };
}
