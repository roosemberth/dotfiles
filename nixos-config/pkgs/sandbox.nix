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
  snooze = callPackage ./snooze {};
}
