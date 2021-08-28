{ callPackage, fetchFromGitHub, pkgs, stdenv, lib }:
let
  liblms7002m = callPackage ./liblms7002m.nix {};

  libusb3380 = stdenv.mkDerivation {
    name = "libusb3380";
    version = "0.0.1-2-git-2019083101";
    nativeBuildInputs = with pkgs; [cmake pkgconfig];
    buildInputs = [ pkgs.libusb1 ];
    outputs = [ "out" "dev" ];

    src = fetchFromGitHub {
      owner = "xtrx-sdr";
      repo = "libusb3380";
      rev = "da900c76f1d34a2af104eda7ff3e6439c0f59241";
      sha256 = "0671kjx7a5cbkgdzgdizqaxyzw899agrdclf4sj4waiwdlqjfwam";
    };

    meta = with lib; {
      description = "libusb3380 internal";
      homepage = https://github.com/xtrx-sdr/libusb3380;
      license = licenses.lgpl21;
    };
  };

in
stdenv.mkDerivation {
  name = "libxtrxll";
  version = "0.0.1-git-2021082801";
  nativeBuildInputs = with pkgs; [ cmake pkgconfig ];
  buildInputs = [ liblms7002m libusb3380 pkgs.libusb1 ];
  outputs = [ "out" "dev" ];

  dontStrip = true;
  cmakeFlags = "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DCMAKE_BUILD_TYPE=Debug";
  CFLAGS = " -ggdb -Og -O0";
  CXXFLAGS = " -ggdb -Og -O0";

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "libxtrxll";
    rev = "1b6eddfbedc700efb6f7e3c3594e43ac6ff29ea4";
    sha256 = "sha256-jNirQbpGcKnoU+SyhJBzc22O0dt/pf6BkQI+jHPUuZA=";
  };

  postInstall = ''
    install -m 644 -D $src/mod_usb3380/udev/50-xtrx-usb3380.rules $out/etc/udev/rules.d/50-xtrx-usb3380.rules
  '';
}
