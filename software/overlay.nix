final: prev: let
  nvim = final.callPackage ./nvim-roos {};
  xtrx = final.callPackage ./xtrx-sdr {};
in {
  ensure-nodatacow-btrfs-subvolume =
    final.callPackage ./ensure-nodatacow-btrfs-subvolume.nix { };

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

  kubic = with final; buildGoModule rec {
    pname = "kubic";
    version = "0.0.4";
    src = fetchFromGitHub {
      owner = "tty2";
      repo = "kubic";
      rev = "v${version}";
      hash = "sha256-QExJ8MnEmNuzFPCNPPw7nMfGDDB4H8dmTPYTNaqlRSk=";
    };
    vendorHash = null;
    meta = with lib; {
      description = "k8s tui";
      homepage = "https://github.com/tty2/kubic";
      maintainers = with maintainers; [ roosemberth ];
      platforms = platforms.all;
    };
  };

  layout-trees-generator = with final; rustPlatform.buildRustPackage rec {
    pname = "layout-trees-generator";
    version = "0.1.0";
    src = fetchFromGitLab {
      owner = "roosemberth";
      repo = "layout-trees";
      rev = version;
      hash = "sha256-/SBcYFNPIDxVqIGiDXr03ETQoQp/DJ6Jkha3GuhFRdY=";
    };
    cargoSha256 = "sha256-Emn7MHX1rPgDUuGuxYTEwCNjj0Qyx23pxdlxaZ0Nt/M=";

    nativeBuildInputs = [ makeWrapper ];

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

    postInstall = ''
      wrapProgram $out/bin/layout-trees-generator \
        --prefix PATH : ${lib.makeBinPath [ pkgs.systemd ]}
    '';
  };

  bitbox-bridge = with final; rustPlatform.buildRustPackage rec {
    pname = "bitbox-bridge";
    version = "1.5.1";
    src = fetchFromGitHub {
      owner = "digitalbitbox";
      repo = "bitbox-bridge";
      rev = "v${version}";
      hash = "sha256-pxxTdbUwsw5wqlG77BqLrBzLvuOn46qfWMEQRyvXVOU=";
    };
    cargoLock = {
      lockFile = "${src}/Cargo.lock";
      outputHashes."hidapi-2.3.1" =
        "sha256-uv2yyaPNLpB2Og5LIKxop9swXwHniuC7FQPg01yAWLk=";
    };
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ udev.dev ];

    meta = with lib; {
      homepage = "https://github.com/digitalbitbox/bitbox-bridge";
      license = licenses.asl20;
      maintainers = [ maintainers.tailhook ];
    };
  };

  inherit (xtrx) libxtrx libxtrxll libxtrxdsp liblms7002m;

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

  nvim-roos-core = nvim.core;
  nvim-roos-essential = nvim.essential;
  nvim-roos-full = nvim.full;

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

  recla-certs = with final; stdenv.mkDerivation {
    name = "recla-certs";
    version = "23012601";
    srcs = [
      (pkgs.fetchurl {
        url = "https://www.rec.la/rec.la-bundle.crt";
        hash = "sha256-XO5nfvZlpRAoxi6keyUq6nCrw8FkiAGfivOV1q4Gt0U=";
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

  sdrpp = prev.sdrpp.override { soapysdr-with-plugins = final.soapysdr-with-plugins; };
  sdrangel = prev.sdrangel.override { soapysdr-with-plugins = final.soapysdr-with-plugins; };

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

  swaynotificationcenter = prev.swaynotificationcenter.overrideAttrs(o: {
    patches = o.patches or [] ++ [
      (final.writeText "1-remove-superfluous-trigger-on-example-config.patch" ''
        --- a/src/config.json.in
        +++ b/src/config.json.in
        @@ -24,17 +24,7 @@
           "hide-on-clear": false,
           "hide-on-action": true,
           "script-fail-notify": true,
        -  "scripts": {
        -    "example-script": {
        -      "exec": "echo 'Do something...'",
        -      "urgency": "Normal"
        -    },
        -    "example-action-script": {
        -      "exec": "echo 'Do something actionable!'",
        -      "urgency": "Normal",
        -      "run-on": "action"
        -    }
        -  },
        +  "scripts": {},
           "notification-visibility": {
             "example-name": {
               "state": "muted",
      '')
    ];
  });

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

  youtube-dl = final.yt-dlp.override { withAlias = true; };
}
