{ pkgs }: {
  relm4 = with pkgs; stdenv.mkDerivation {
    name = "relm4-env";
    nativeBuildInputs = [
      rustc
      cargo
      clippy
      rustfmt
      rls
      rustup

      pkgconfig
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
}
