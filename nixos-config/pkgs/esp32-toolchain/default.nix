{ pkgs, stdenv, fetchgit, writeText }:

stdenv.mkDerivation rec {
  name = "xtensa-esp32-elf";
  version = "1.22.x";
  src = fetchgit {
    url = "https://github.com/espressif/crosstool-NG.git";
  # branch = "xtensa-${version}";
    rev = "6c4433a51e4f2f2f9d9d4a13e75cd951acdfa80c";
    sha256 = "03qg9vb0mf10nfslggmb7lc426l0gxqhfyvbadh86x41n2j6ddg6";
  };

  nativeBuildInputs = with pkgs; [
    autoconf automake aria coreutils curl cvs
    gcc git python which wget
  ];

  buildInputs = with pkgs; [
    bison flex gperf help2man libtool ncurses texinfo
  ];

  configurePhase = ''
    ./bootstrap
    ./configure --enable-local --disable-static
    make install
  '';

  buildPhase = ''
    ./ct-ng xtensa-esp32-elf
    ./ct-ng build
  '';
}
