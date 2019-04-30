{ nixpkgs ? import <nixpkgs> {} }:
let
in with nixpkgs;
{
  python-mpd2 = python3Packages.buildPythonApplication {
    pname = "python-mpd2";
    version = "1.0.0";
    src = fetchFromGitHub {
      owner = "Mic92";
      repo = "python-mpd2";
      rev = "fc2782009915d9b642ceef6e4d3b52fa6168998b";
      sha256 = "03d4fvflrz0z4pymmjqcg4zldjsxbzmns0c70vc208lcdpnzpz6p";
    };

    doCheck = false;
  };

  indicator-kdeconnect = stdenv.mkDerivation rec {
    name = "indicator-kdeconnect";
    version = "0.9.4";

    src = fetchFromGitHub {
      owner = "bajoja";
      repo = "indicator-kdeconnect";
      rev = "${version}";
      sha256 = "0ns05cm38mbhlh6xzdll921hxk4vl23lvjb21x056yivxafrqvl8";
    };

    nativeBuildInputs = with pkgs;[
      pkgconfig
      cmake
      vala
    ];

    buildInputs = with pkgs;[
      gnome3.libgee
      gsettings-desktop-schemas
      json-glib
      libappindicator-gtk3

      wrapGAppsHook
    ];

    propagatedBuildInputs = with python3.pkgs;[
      requests_oauthlib
      pygobject3
    ] ++ [
      gnome3.nautilus-python
      kdeconnect
      kde-cli-tools  # kcmshell5 needed to configure kdeconnect
    ];

    prePatch = ''
      substituteInPlace src/DeviceIndicator.vala --replace '"kcmshell5"' '"${pkgs.kde-cli-tools}/bin/kcmshell5"'
    '';

    PKG_CONFIG_LIBNAUTILUS_EXTENSION_EXTENSIONDIR = "${placeholder "out"}/lib/nautilus/extensions-3.0";
  };
}
