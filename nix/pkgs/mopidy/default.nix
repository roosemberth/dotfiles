{ buildEnv
, lib
, makeWrapper
, mopidy
, mopidyPackages
, pipewire
, python3
}: let
  mopidy' = mopidy.overrideAttrs (o: {
    buildInputs = (o.buildInputs or []) ++ [ pipewire ];
  });
in buildEnv {
  name = "mopidy-with-extensions-${mopidy.version}";
  paths = lib.closePropagation (with mopidyPackages; [
    mopidy-spotify mopidy-iris mopidy-mpd mopidy-local
  ]);
  pathsToLink = [ "/${python3.sitePackages}" ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    makeWrapper ${mopidy'}/bin/mopidy $out/bin/mopidy \
    --prefix PYTHONPATH : $out/${python3.sitePackages}
  '';
}
