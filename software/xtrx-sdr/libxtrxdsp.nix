{ fetchFromGitHub, lib, pkgs, stdenv }:

stdenv.mkDerivation {
  name = "libxtrxdsp";
  version = "0.0.1-git-2023020301";
  nativeBuildInputs = with pkgs; [ cmake pkgconfig ];
  outputs = [ "out" "dev" ];

  src = fetchFromGitHub {
    owner = "myriadrf";
    repo = "libxtrxdsp";
    rev = "271f5e60e40dd578c0db5f50ceb7fd6b7119c5ef";
    hash = "sha256-I2M6Zj4PTHRBQ7AZWnBZjR9eYj8dKp1WvTWfVfVoNsg=";
  };

  meta = with lib; {
    description = "Low-level XTRX hardware abstraction library.";
    homepage = https://github.com/myriadrf/libxtrxdsp;
    license = licenses.asl20;
  };
}
