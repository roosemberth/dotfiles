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

  matrix-alertmanager-receiver = with final; buildGoModule rec {
    pname = "matrix-alertmanager-receiver";
    version = "0.1.2";
    src = fetchgit {
      url = "https://git.sr.ht/~fnux/matrix-alertmanager-receiver";
      rev = "refs/tags/${version}";
      sha256 = "sha256-F6Cn0lmASAjWGEBCmyLdfz4r06fDTEfZQcynfA/RRtI=";
    };
    vendorSha256 = "sha256-7tRCX9FzOsLXCTWWjLp3hr1kegt1dxsbCKfC7tICreo=";
    meta = with lib; {
      description = "Forwards prometheus alerts to Matrix rooms";
      homepage = "https://git.sr.ht/~fnux/matrix-alertmanager-receiver";
      maintainers = with maintainers; [ roosemberth ];
      platforms = platforms.all;
    };
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

  nvim-roos-core = nvim.core;
  nvim-roos-essential = nvim.essential;
  nvim-roos-full = nvim.full;

  mopidy-roos = final.callPackage ./mopidy {};
  recla-certs = with final; stdenv.mkDerivation {
    name = "recla-certs";
    version = "22011001";
    srcs = [
      (pkgs.fetchurl {
        url = "https://www.rec.la/rec.la-bundle.crt";
        hash = "sha256-BON3IVjZ5xD3OJGBLDfhe1gnyb/hTXp5A/m8NuBtBLw=";
      })
      (pkgs.fetchurl {
        url = "https://www.rec.la/rec.la-key.pem";
        hash = "sha256-biwuc3HQBxXYzYKOwMYhHNWrP5z7ytmZY1Bgk5TolxI=";
      })
    ];
    phases = [ "buildPhase" ];
    buildPhase = ''
      mkdir "$out"
      for _src in $srcs; do
        cp "$_src" "$out/$(basename "$(stripHash "$_src")")"
      done
    '';
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
  xtrx = final.callPackage ./xtrx-sdr {};

  soapysdr-with-plugins = prev.soapysdr-with-plugins.override {
    extraPackages = with final; [
      limesuite
      soapyairspy
      soapyaudio
      soapybladerf
      soapyhackrf
      soapyremote
      soapyrtlsdr
      soapyuhd
      xtrx.libxtrx
    ];
  };

  gnuradio-with-soapy = with final; let
    soapy = soapysdr-with-plugins;
    extraSoapyPkgs = [ xtrx.libxtrx ];
    modulesVersion = v: with final.lib;
      versions.major v + "." + versions.minor v;
    soapyModulesPath = "lib/SoapySDR/modules" + (modulesVersion soapy.version);
    soapyPkgsSearchPath = lib.makeSearchPath soapyModulesPath extraSoapyPkgs;
  in gnuradio.override {
    extraMakeWrapperArgs = [
      "--prefix" "SOAPY_SDR_PLUGIN_PATH" ":" "${soapyPkgsSearchPath}"
    ];
    extraPythonPackages = with gnuradio.unwrapped.python.pkgs; [
      soapysdr
    ];
  };

  youtube-dl = final.yt-dlp.override { withAlias = true; };
}
