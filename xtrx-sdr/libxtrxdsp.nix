{ fetchFromGitHub, pkgs, stdenv }:

stdenv.mkDerivation {
  name = "libxtrxdsp";
  version = "0.0.1-git-2019083101";
  nativeBuildInputs = with pkgs; [ cmake pkgconfig ];
  outputs = [ "out" "dev" ];

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "libxtrxdsp";
    rev = "eec28640c0ebd5639b642f07b310a0a0d02d9834";
    sha256 = "1vsrqkhd2lss70mcqbw3gmnjdnnd41g1plkyqdwj7bbvc4ng2m8w";
  };
}
