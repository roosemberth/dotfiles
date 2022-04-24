{ config, pkgs, secrets, ... }: {
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers."collabora-code" = {
    image = "collabora/code";
    ports = [ "42085:9980" ];
    environment = {
      inherit (secrets.collabora) username password;
      aliasgroup1 = "https://nextcloud\\.orbstheorem\\.ch";
      server_name = "https://collabora\\.orbstheorem\\.ch";
      extra_params = "--o:ssl.termination=true --o:ssl.enable=false";
    };
  };
}
