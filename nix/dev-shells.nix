{ pkgs }: {
  c = with pkgs; stdenv.mkDerivation {
    name = "c-cpp-dev-env";
    nativeBuildInputs = [ clang clang-tools cmake ctags gnumake ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  embedded = with pkgs; stdenv.mkDerivation {
    name = "embedded-systems-dev-env";
    nativeBuildInputs = [ clang clang-tools cmake ctags gnumake platformio ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  flutter-web = with pkgs; stdenv.mkDerivation {
    name = "flutter-web-env";
    CHROME_EXECUTABLE = "${chromium}/bin/chromium";
    nativeBuildInputs = [ chromium flutter dart ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  hs = with pkgs; stdenv.mkDerivation {
    name = "haskell-dev-env";
    nativeBuildInputs = [
      (ghc.withHoogle (p: with p; [
        QuickCheck
        aeson
        generic-arbitrary
        optparse-applicative
        parsec
        protolude
        quickcheck-instances
        yaml
      ]))
      haskellPackages.fast-tags
      haskell-language-server
      stack
    ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  js = with pkgs; stdenv.mkDerivation {
    name = "javascript-dev-env";
    nativeBuildInputs = [ nodejs yarn ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  py = with pkgs; stdenv.mkDerivation {
    name = "python3-dev-env";
    nativeBuildInputs = [
      (python3.withPackages (p: with p;[
        alembic
        beautifulsoup4
        flask
        ipdb
        ipython
        jinja2
        mypy
        pip
        pwntools
        pytest
        requests
        sqlalchemy
        tox
        virtualenv
        yaml
      ]))
      python3Packages.black
    ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
  relm4 = with pkgs; stdenv.mkDerivation {
    name = "relm4-env";
    nativeBuildInputs = [
      rustc
      cargo
      clippy
      rustfmt
      rls
      rustup

      pkg-config
      gcc
      glib
      cairo
      pango
      graphene
      gdk-pixbuf
      gtk4
      xdg-desktop-portal
      wrapGAppsHook
    ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  };
}
