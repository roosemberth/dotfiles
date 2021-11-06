{ config, pkgs, secrets, ... }: {
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers."powerflow-flutter-app" = {
    image = "registry.gitlab.com/roosemberth/powerflow/flutter-app:latest";
    ports = [ "45100:80" ];
  };
}
