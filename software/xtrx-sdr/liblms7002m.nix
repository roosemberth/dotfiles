{ fetchFromGitHub, lib, pkgs, stdenv }:

stdenv.mkDerivation {
  name = "liblms7002m";
  version = "0.0.1-git-2020051801";
  nativeBuildInputs = with pkgs; [ cmake pkg-config python3Packages.cheetah3 ];
  outputs = [ "out" "dev" ];

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "liblms7002m";
    rev = "b07761b7386181f0e6a35158456b75bce14f2aca";
    hash = "sha256-tI6gm/Juvaya1D9byjwZtm7zuoKTbL+07hTgoI9UAg8=";
  };

  meta = with lib; {
    description = "Compact LMS7002M library suitable for resource-limited MCUs";
    homepage = https://github.com/xtrx-sdr/libusb3380;
    license = licenses.lgpl21;
  };
}
