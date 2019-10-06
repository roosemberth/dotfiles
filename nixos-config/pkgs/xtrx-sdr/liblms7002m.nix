{ fetchFromGitHub, pkgs, stdenv }:

stdenv.mkDerivation {
  name = "liblms7002m";
  version = "0.0.1-git-2019083101";
  nativeBuildInputs = with pkgs; [ cmake pkgconfig python27Packages.cheetah ];
  outputs = [ "out" "dev" ];

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "liblms7002m";
    rev = "d7bab43df6fd0917b8087238007716d98e837cf4";
    sha256 = "0xhybkwnl11cf5lpk0kd1k249i2v65pjvsg34i3kcpwzca4rmz7g";
  };
}
