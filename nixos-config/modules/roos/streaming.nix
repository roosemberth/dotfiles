{ config, pkgs, lib, ... }: {
  options.roos.streaming.enable = lib.mkEnableOption "Streaming support";

  config = lib.mkIf config.roos.streaming.enable {
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
