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

  dbus-action = with final; python3.pkgs.buildPythonApplication rec {
    pname = "dbus-action";
    version = "1.5";
    disabled = python3Packages.pythonOlder "3.6";

    src = fetchFromGitHub {
      owner = "bulletmark";
      repo = "dbus-action";
      rev = "${version}";
      hash = "sha256-8emQhPmqRnIuvKYaNEO1pQ0or21DBxk7WUpmkMTYcPc=";
    };
    dontUnpack = true;
    format = "other";

    propagatedBuildInputs = with python3.pkgs; [
      dbus-python pygobject3 ruamel-yaml
    ];
    nativeBuildInputs = [ wrapGAppsNoGuiHook gobject-introspection ];

    dontWrapGApps = true;
    preFixup = ''makeWrapperArgs+=("''${gappsWrapperArgs[@]}")'';

    installPhase = ''
      mkdir -p "$out/bin"
      cp $src/dbus-action "$out/bin/dbus-action"
      chmod +x "$out/bin/dbus-action"
    '';

    meta = with lib; {
      description = "Watch D-Bus to action configured commands on specific events";
      homepage = "https://github.com/bulletmark/dbus-action";
      maintainers = with maintainers; [ roosemberth ];
      platforms = platforms.linux;
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
    propagatedBuildInputs = [ python3.pkgs.pulsectl jq foot fzf sway ];
    installPhase = ''
      mkdir -p "$out/bin"
      cp $src "$out/bin/remap-pa-client"
      chmod +x "$out/bin/remap-pa-client"
    '';
  };

  nvim-roos-core = nvim.core;
  nvim-roos-essential = nvim.essential;
  nvim-roos-full-coc-lsp = nvim.full-coc-lsp;
  nvim-roos-full-native-lsp = nvim.full-native-lsp;
  nvim-roos-full = nvim.full-coc-lsp;

  mopidy-roos = final.callPackage ./mopidy {};
  greenzz-server = final.callPackage ./greenzz-server {};
  recla-certs = with final; stdenv.mkDerivation {
    name = "recla-certs";
    version = "22011001";
    srcs = [
      (pkgs.fetchurl {
        url = "https://www.rec.la/rec.la-bundle.crt";
        hash = "sha256:017fc106ncrnx958pl4zwidi2lg8bi640c0mqgljabjmjqa92g8s";
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

  # Can't overrideAttrs over prev: vendorSha256 doesn't get updated...
  prometheus-bind-exporter = let
    pkg =
      { lib, buildGoModule, fetchFromGitHub, nixosTests }:
      buildGoModule rec {
        pname = "bind_exporter";
        version = "0.5.0";

        src = fetchFromGitHub {
          rev = "v${version}";
          owner = "prometheus-community";
          repo = "bind_exporter";
          sha256 = "sha256-ta+uy0FUEMcL4SW1K3v2j2bfDRmdAIz42MKPsNj4FbA=";
        };

        vendorSha256 = "sha256-L0jZM83u423tiLf7kcqnXsQi7QBvNEXhuU+IwXXAhE0=";

        passthru.tests = { inherit (nixosTests.prometheus-exporters) bind; };

        meta = with lib; {
          description = "Prometheus exporter for bind9 server";
          homepage = "https://github.com/digitalocean/bind_exporter";
          license = licenses.asl20;
          maintainers = with maintainers; [ rtreffer ];
          platforms = platforms.unix;
        };
      };
  in final.callPackage pkg {};
  btrbk = prev.btrbk.overrideAttrs(o: {
    #patches = o.patches or [] ++ [
    #  ./0001-ssh_filter_btrbk-Allow-quoted-paths-when-using-sudo.patch
    #];
  });
  user-mounts-generator = with final; rustPlatform.buildRustPackage {
    pname = "user-mounts-generator";
    version = "0.1.0";
    src = ./user-mounts-generator;
    cargoLock.lockFile = ./user-mounts-generator/Cargo.lock;

    meta = with lib; {
      description = ''
        Generates a set of systemd mount units based on a layout tree of btrfs
        subvolumes.

        The subvolumes in the layout tree will be mounted at the specified
        subpath under the "destination path" of the tree.
      '';
      homepage = "https://github.com/BurntSushi/ripgrep";
      license = licenses.unlicense;
      maintainers = [ maintainers.tailhook ];
    };
  };
}
