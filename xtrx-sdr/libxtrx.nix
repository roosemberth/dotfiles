{ callPackage
, fetchFromGitHub
, fetchurl
, pkgs
, qmake
, qtbase
, soapysdr
, stdenv
, wrapQtAppsHook
}:
let
  libxtrxdsp = callPackage ./libxtrxdsp.nix {};
  libxtrxll = callPackage ./libxtrxll.nix {};
  liblms7002m = callPackage ./liblms7002m.nix {};

  qcustomplot2 = stdenv.mkDerivation {
    name = "qcustomplot";
    version = "2.0.1";
    nativeBuildInputs = with pkgs; [ qmake pkgconfig wrapQtAppsHook ];
    outputs = [ "out" "dev" ];

    cmakeFlags = [ "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" ];

    src = fetchurl {
      url = "https://www.qcustomplot.com/release/2.0.1/QCustomPlot-source.tar.gz";
      sha256 = "1r1z82r017ffp76np1xnp5y2f54jhll398k80441s9gkvr3ywk2p";
    };
    preConfigure = ''
      cat <<- EOF > qcustomplot.pro
        QT += core gui

        DEFINES += QCUSTOMPLOT_COMPILE_LIBRARY
        TEMPLATE = lib
        CONFIG += link_pkgconfig shared
        # TARGET = qcustomplot
        SOURCES += ./qcustomplot.cpp
        HEADERS += ./qcustomplot.h

        lib.path = lib
        target.path = lib
        INSTALLS += target
      EOF
    '';
  };
in
stdenv.mkDerivation {
  name = "libxtrx";
  version = "0.0.1-git-2019083101";
  nativeBuildInputs = with pkgs; [ cmake pkgconfig ];
  buildInputs = [
    liblms7002m
    libxtrxdsp
    libxtrxll
    qtbase
    qcustomplot2
    wrapQtAppsHook
    soapysdr
  ];

  # Temporary disable
  unpackCommand = "false";

  postInstall = ''
    install -m 755 -D $out/lib/xtrx/test_xtrx $out/bin/test_xtrx
  '';

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "libxtrx";
    rev = "b3c491da010126d4a5bff0b6d5f23d83dfe1f28c";
    sha256 = "0hzacf03yldcbki7i5blswnyr9a920ygklnn0y5s3qkv1z114awk";
  };
}
