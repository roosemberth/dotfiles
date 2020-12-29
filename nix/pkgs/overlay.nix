final: prev: {
  mfgtools = final.callPackage ./mfgtools { };
  ensure-nodatacow-btrfs-subvolume =
    final.callPackage ./ensure-nodatacow-btrfs-subvolume.nix { };
  matrix-federation-tester = with final; buildGoModule rec {
    pname = "matrix-federation-tester";
    version = "0.2";
    src = fetchFromGitHub {
      owner = "matrix-org";
      repo = "matrix-federation-tester";
      rev = "v${version}";
      sha256 = "sha256-Z1/2hWHsmLtOeHUgr/Jr0FF8WRsbUGWaKbiqTdSvKDU=";
    };
    vendorSha256 = "sha256-1zbNYB6S72/uzoeUMdaCQjzKOZ1xTlGc3oseXWGyetA=";
    meta = with lib; {
      description = "Tester for matrix federation written in golang";
      homepage = "https://github.com/matrix-org/matrix-federation-tester";
      maintainers = with maintainers; [ roosemberth ];
      platforms = platforms.linux;
    };
  };
  wshowkeys = with final; stdenv.mkDerivation {
    name = "wshowkeys";
    version = "0.0-git";
    nativeBuildInputs = with pkgs; [ninja meson pkgconfig cmake];
    buildInputs = with pkgs; [
      cairo libinput pango udev wayland libxkbcommon wayland-protocols
    ];
    src = fetchGit {
      url = "https://git.sr.ht/~sircmpwn/wshowkeys";
      rev = "6388a49e0f431d6d5fcbd152b8ae4fa8e87884ee";
    };
  };
}
