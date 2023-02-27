{ config, pkgs, lib, ... }: with lib;
let
  cfg = config.roos.nginx-fileshare;
in {
  options.roos.nginx-fileshare = {
    enable = mkEnableOption "NGINX-based cloud";
    directory = mkOption {
      type = types.str;
      description = "Base directory containing all files.";
    };
    host = mkOption {
      type = types.str;
      description = "Virtual host serving files";
      default = "files.rec.la";
    };
  };

  config = mkIf config.roos.nginx-fileshare.enable {
    services.nginx.enable = true;
    services.nginx.virtualHosts."${cfg.host}" = {
      onlySSL = true;
      sslCertificate = "${pkgs.recla-certs}/rec.la-bundle.crt";
      sslCertificateKey = "${pkgs.recla-certs}/rec.la-key.pem";
      root = cfg.directory;
      locations."/".extraConfig = "return 307 /public/;";
      locations."/public".extraConfig = "autoindex on;";
      locations."~ ^/(?!public)(.+?)/(.*)$".extraConfig = ''
        alias ${cfg.directory}/usr/$1/$2;
        autoindex on;
        auth_basic "Speak friend and come in";
        auth_basic_user_file /srv/shared/usr/$1/.htpasswd;
      '';
      extraConfig = ''
        # NGINX does not have enough information to provide user with an absolute URL.
        absolute_redirect off;
      '';
    };
  };
}
