{ pkgs }:
with pkgs;
let
  liblms7002m = callPackage ./liblms7002m.nix {};

  libxtrx = pkgs.libsForQt5.callPackage ./libxtrx.nix {};

  libxtrxdsp = callPackage ./libxtrxdsp.nix {};

  libxtrxll = callPackage ./libxtrxll.nix {};
in
stdenvNoCC.mkDerivation {
  name = "libxtrx-all";
  version = "0.0.2-git-2019083101";

  buildInputs = [
    liblms7002m.dev
    libxtrx
    libxtrxdsp
    libxtrxll
  ];
  unpackPhase = "true";
  buildCommand = "touch $out";

  meta = with stdenv.lib; {
    description = "ALL XTRX family libraries";
    longDescription = ''
      This is a repackaging work for NixOS, based in the official Debian package
      provided by Fairwaves, Inc.

      Since the upstream repository only contains a packaging script, this
      package has no sources but rather the same dependencies as the original
      one.
    '';
    homepage = https://github.com/xtrx-sdr/libxtrx-all;
    license = licenses.lgpl21;
    maintmainers = [ maintmainers.roosemberth ];
  };
}
