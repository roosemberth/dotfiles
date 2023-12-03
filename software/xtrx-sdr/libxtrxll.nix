{ callPackage, fetchFromGitHub, lib, pkgs, stdenv }:
let
  liblms7002m = callPackage ./liblms7002m.nix {};

  libusb3380 = stdenv.mkDerivation {
    name = "libusb3380";
    version = "0.0.1-2-git-2023020301";
    nativeBuildInputs = with pkgs; [cmake pkg-config];
    buildInputs = [ pkgs.libusb1 ];
    outputs = [ "out" "dev" ];

    src = fetchFromGitHub {
      owner = "myriadrf";
      repo = "libusb3380";
      rev = "92d102a6b13744b7151560293c896d6fff70ce3e";
      hash = "sha256-UpfzXuDMp/1nRD6UFhKHyTSIHKxqQPzMuQq3nV/a3PE=";
    };

    meta = with lib; {
      description = "USB3380 abstraction layer for libusb";
      homepage = https://github.com/xtrx-sdr/libusb3380;
      license = licenses.asl20;
    };
  };

in
stdenv.mkDerivation {
  name = "libxtrxll";
  version = "0.0.1-git-2021082801";
  nativeBuildInputs = with pkgs; [ cmake pkg-config ];
  buildInputs = [ liblms7002m libusb3380 pkgs.libusb1 ];
  outputs = [ "out" "dev" ];

  dontStrip = true;
  cmakeFlags = [ "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" "-DCMAKE_BUILD_TYPE=Debug" ];
  CFLAGS = " -ggdb -Og -O0";
  CXXFLAGS = " -ggdb -Og -O0";

  src = fetchFromGitHub {
    owner = "myriadrf";
    repo = "libxtrxll";
    rev = "78fb3657b8e6aeb6977813fbbd0ba771ac16433c";
    hash = "sha256-irKXnC+m3Ecmtv8aXEZGuE9xy0apneuGUOCzu4lb/9k=";
  };

  postInstall = ''
    install -m 644 -D $src/mod_usb3380/udev/50-xtrx-usb3380.rules $out/etc/udev/rules.d/50-xtrx-usb3380.rules
  '';

  meta = with lib; {
    description = "Low-level XTRX hardware abstraction library.";
    homepage = https://github.com/myriadrf/libusb3380;
    license = licenses.asl20;
  };
}
