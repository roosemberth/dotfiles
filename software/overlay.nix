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
    version = "0.2.1";
    src = fetchFromGitLab {
      owner = "roosemberth";
      repo = "layout-trees";
      rev = version;
      hash = "sha256-KuUaY7maDTM5/sBpDzObfhwHZW3zuPxafspBspn7amo=";
    };
    cargoHash = "sha256-68R08gc0lkfsToC5Wfc1UEKbga2Bo0iHh6+te9mvSV4=";

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
      maintainers = [ maintainers.roosemberth ];
    };

    postInstall = ''
      wrapProgram $out/bin/layout-trees-generator \
        --prefix PATH : ${lib.makeBinPath [ pkgs.systemd ]}
    '';
  };

  bdk-kit = with final; rustPlatform.buildRustPackage rec {
    pname = "bdk-cli";
    version = "6ac12a1b7bf8cdd8c7f60fb8c1b4acf076762991";
    src = fetchFromGitHub {
      owner = "bitcoindevkit";
      repo = "bdk-cli";
      rev = version;
      hash = "sha256-zTVK2JAjFlDUHR4ba6ddgBtbEkRrBiHWtLLFN5C4Gl8=";
    };
    cargoHash = "sha256-weOM4asAI2Y547vB7Xodzv0sCHoauqgDdaHSBFGOYig=";

    meta = with lib; {
      description = ''
        A CLI wallet library and REPL tool to demo and test the BDK library.
      '';
      homepage = "https://github.com/bitcoindevkit/bdk-cli";
      license = licenses.mit;
      maintainers = [ maintainers.roosemberth ];
    };
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
    vendorHash = "sha256-7tRCX9FzOsLXCTWWjLp3hr1kegt1dxsbCKfC7tICreo=";
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
