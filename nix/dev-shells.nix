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
}
