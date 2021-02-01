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
      default = "${config.networking.hostName}.orbstheorem.ch";
    };
  };

  config = mkIf config.roos.nginx-fileshare.enable {
    services.nginx.enable = true;
    services.nginx.virtualHosts."${cfg.host}" = {
      root = cfg.directory;
      locations."/".extraConfig = "return 307 /public/;";
      locations."^~ /public".extraConfig = "autoindex on;";
      locations."~ ^/(.+?)/(.*)$".extraConfig = ''
        alias ${cfg.directory}/usr/$1/$2;
        autoindex on;
        auth_basic "Speak friend and come in";
        auth_basic_user_file /srv/shared/usr/$1/.htpasswd;
      '';
    };
  };
}
