{ config, pkgs, lib, ... }: {
  options.roos.streaming.enable = lib.mkEnableOption "Streaming support";

  config = lib.mkIf config.roos.streaming.enable {
    environment.systemPackages =
    let
      libshout_2_4_1 = pkgs.libshout.overrideAttrs (old: rec {
        name = "libshout-2.4.1";  # libshout 2.4.2 causes shout2send not to send auth information

        src = pkgs.fetchurl {
          url = "http://downloads.xiph.org/releases/libshout/${name}.tar.gz";
          sha256 = "0kgjpf8jkgyclw11nilxi8vyjk4s8878x23qyxnvybbgqbgbib7k";
        };
      });
    in with pkgs.gst_all_1; [
      gstreamer.dev gst-plugins-base gst-plugins-bad gst-libav
      (gst-plugins-good.override { libshout = libshout_2_4_1; })
    ];
    environment.pathsToLink = ["/lib"];

    services = {
      icecast = {
        enable = true;
        hostname = "Triglav";
        admin.password = "qzp3m4bcj";
        extraConf = let
          mkmount = name: ''
            <mount>
              <mount-name>/${name}.ogg</mount-name>
              <password>hackme</password>
            </mount>
          '';
          mounts = ["mopidy" "public" "triglav"];
        in lib.concatStrings (map mkmount mounts);
      };
      nginx = {
        enable = true;
        virtualHosts."triglav.r.orbstheorem.ch".locations = {
          "/stream.ogg".proxyPass = "http://127.0.0.1:8000/public.ogg";
        };
      };
    };
  };
}
