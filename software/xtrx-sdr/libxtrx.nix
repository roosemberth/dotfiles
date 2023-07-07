{ callPackage
, fetchFromGitHub
, fetchurl
, lib
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
    version = "2.1.1";
    nativeBuildInputs = with pkgs; [ qmake pkgconfig wrapQtAppsHook ];
    outputs = [ "out" "dev" ];

    cmakeFlags = [ "-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON" ];

    src = fetchurl {
      url = "https://www.qcustomplot.com/release/2.1.1/QCustomPlot-source.tar.gz";
      hash = "sha256-Xi0i3sd5248B81fL2yXlT7z5ca2u516ujXrSRESHGC8=";
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

    meta = with lib; {
      description = "Qt C++ widget for plotting and data visualization.";
      homepage = https://github.com/myriadrf/libxtrx;
      license = licenses.asl20;
    };
  };
in
stdenv.mkDerivation {
  name = "libxtrx";
  version = "0.0.1.2-git-2023020301";
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
    owner = "myriadrf";
    repo = "libxtrx";
    rev = "d9599fbf5be2714e6933c5a15acb3d8c57669859";
    hash = "sha256-L/vlL8NT+uuxZ+o5/AxIkp8LcE7a+fo8QvBF/qT2h4A=";
  };

  meta = with lib; {
    description = "High-level XTRX API library";
    homepage = https://github.com/myriadrf/libxtrx;
    license = licenses.asl20;
  };
}
