final: prev: let
  nvim = final.callPackage ./nvim-roos {};
in {
  mfgtools = final.callPackage ./mfgtools { };
  ensure-nodatacow-btrfs-subvolume =
    final.callPackage ./ensure-nodatacow-btrfs-subvolume.nix { };
  pass-keyrings = final.callPackage ./pass-keyring.nix { };
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
  wl-clipboard-x11 = with final; stdenv.mkDerivation rec {
    name = "wl-clipboard-x11";
    version = "5";
    src = fetchFromGitHub {
      owner = "brunelli";
      repo = "wl-clipboard-x11";
      rev = "v${version}";
      sha256 = "sha256-i+oF1Mu72O5WPTWzqsvo4l2CERWWp4Jq/U0DffPZ8vg=";
    };
    makeFlags = [ "PREFIX=$(out)" ];
  };
  wireplumber = assert (builtins.hasAttr "wireplumber" final.pkgs);
  with final; stdenv.mkDerivation {
    name = "wireplumber";
    version = "0.4.1";
    nativeBuildInputs = with pkgs; [
      meson ninja pkg-config lua5_4 doxygen
      (python3.withPackages(p: with p; [lxml]))
    ];
    mesonFlags = [
      "-Dsystem-lua=true"
      "-Ddoc=disabled" # `hotdoc` not packaged in nixpkgs as of writing
    ];
    buildInputs = with pkgs; [ gobject-introspection pipewire systemd ];
    propagatedBuildInputs = with pkgs; [ glib ];
    src = fetchGit {
      url = "https://gitlab.freedesktop.org/pipewire/wireplumber";
      rev = "b741b2c8c876585eabd6f4d62d62af5b46c0afd0";
    };
  };

  jack-mixer = with final; python3.pkgs.buildPythonApplication {
    name = "jack-mixer";
    version = "release-16";

    src = pkgs.fetchurl {
      url = "https://github.com/jack-mixer/jack_mixer/releases/download/release-16/jack_mixer-16.tar.xz";
      hash = "sha256-yVNc9gbhU04ibh4LwAU2vHCfgINfpEYwqmfcSAxgnfk=";
    };

    format = "other";

    patchPhase = "sed '/add_install_script/d' -i meson.build";
    hardeningDisable = [ "format" ];

    buildInputs = with pkgs; [ libjack2 glib python3 ];
    nativeBuildInputs = with pkgs; [
      meson ninja pkgconfig wrapGAppsHook python3.pkgs.docutils gettextWithExpat
    ];

    propagatedBuildInputs = with python3.pkgs; [
      pygobject3 pycairo xdg gtk3 gobject-introspection
    ];
  };
  remap-pa-client = with final; python3.pkgs.buildPythonApplication {
    pname = "remap-pa-client";
    version = "0.0";
    src = ./remap-pa-client/remap-pa-client.py;
    dontUnpack = true;
    format = "other";
    propagatedBuildInputs = [ python3.pkgs.pulsectl jq alacritty fzf sway ];
    installPhase = ''
      mkdir -p "$out/bin"
      cp $src "$out/bin/remap-pa-client"
      chmod +x "$out/bin/remap-pa-client"
    '';
  };
  nvim-roos = nvim.full;
  nvim-roos-bare = nvim.essential;
  nvim-roos-core = nvim.core;
  mopidy-roos = final.callPackage ./mopidy {};
  alot = assert final.lib.versionAtLeast "0.9.1" prev.alot.version;
    prev.alot.overrideAttrs(o: {
      version = "0.9.1-git";
      src = final.fetchFromGitHub {
        owner = "pazz";
        repo = "alot";
        rev = "a814a7744e0e7d98656980fcdae3ed712a299d8e";
        hash = "sha256-UsWsWGr1zgY4KpSK9bgzXhW6fdqIWTa5A0kddxhyfAs=";
      };
      propagatedBuildInputs = o.propagatedBuildInputs or [] ++
        (with prev.python3Packages; [notmuch2]);
    });
  greenzz-server = final.callPackage ./greenzz-server {};
  kanshi = assert final.lib.versionAtLeast "1.1.0" prev.kanshi.version;
    prev.kanshi.overrideAttrs (o: rec {
    version = "1.2.0";
    src = final.fetchFromGitHub {
      owner = "emersion";
      repo = "kanshi";
      rev = "v${version}";
      sha256 = "RVMeS2qEjTYK6r7IwMeFSqfRpKR8di2eQXhewfhTnYI=";
    };
  });
  waybar = assert final.lib.versionAtLeast "0.9.7" prev.waybar.version;
    prev.waybar.overrideAttrs (o: {
    patches = o.patches or [] ++ [
      (builtins.fetchurl {
        # Pulseaudio controls active sink
        url = "https://github.com/Alexays/Waybar/pull/1169/commits/86a43b904214613b2470db65746367b7721bd929.patch";
        sha256 = "0lrwblkblglrrf1nw2h674w143jh67dzv39ynk509axijzlmyzhx";
      })
    ];
  });
  recla-certs = with final; stdenv.mkDerivation {
    name = "recla-certs";
    # Upstream version is not properly maintained and multiple diverging versions are found.
    version = "21081801";
    src = pkgs.fetchFromGitHub {
      owner = "pryv";
      repo = "rec-la";
      rev = "1ae178733092c08802b20f6f989b8f0af01f1626";
      hash = "sha256-irKOHNpU0sNEr+A154GjT9tX+PkRQL7309em+FxOPZg=";
    };
    phases = [ "buildPhase" ];
    buildPhase = ''cp -r "$src/src/" $out'';
  };
  patchmatrix = with final; stdenv.mkDerivation rec {
    name = "patchmatrix";
    version = "0.26.0";
    src = pkgs.fetchFromGitHub {
      owner = "OpenMusicKontrollers";
      repo = "patchmatrix";
      rev = version;
      hash = "sha256-rR3y5rGzmib//caPmhthvMelAdHRvV0lMRfvcj9kcCg=";
    };
    buildInputs = [ libjack2 glew x11 ];
    nativeBuildInputs = [ meson ninja pkgconfig lv2 cmake ];
  };
  libxtrx-all = final.callPackage ./xtrx-sdr {};
}
