{ config, pkgs, lib, secrets, ... }: with lib;
{
  options.roos.eivd.enable =
    mkEnableOption "Stuff required during my studies at HEIG-VD";

  config = mkIf config.roos.eivd.enable {
    networking.bridges.containers.interfaces = [];
    networking.bridges.containers.rstp = true;

    containers."eivd-mysql" = {
      bindMounts.eivd-mysql-data.mountPoint = "/var/lib/mysql";
      bindMounts.eivd-mysql-data.hostPath = "/var/lib/eivd-mysql/mysql";
      bindMounts.eivd-mysql-data.isReadOnly = false;
      config = {
        services.mysql.enable = true;
        services.mysql.package = pkgs.mariadb;
      };
      ephemeral = true;
      hostBridge = "containers";
      privateNetwork = true;
    };

    roos.sConfig = {
      home.packages = with pkgs; [
        # POO1
        (maven.override { jdk = openjdk14; })
        openjdk14
      ];
    };

    roos.gConfig = {
      home.packages = with pkgs; [ teams ];
    };

    systemd.services.eivd-mysql = {
      description = "Prepare paths used by MySQL in the eivd container.";
      requiredBy = [ "container@eivd-mysql.service" ];
      before = [ "container@eivd-mysql.service" ];
      path = with pkgs; [
        btrfs-progs
        e2fsprogs
        gawk
        utillinux
      ];
      environment.TARGET = "/var/lib/eivd-mysql/mysql";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let tool = "${pkgs.ensure-nodatacow-btrfs-subvolume}";
        in "${tool}/bin/ensure-nodatacow-btrfs-subvolume";
      };
    };
  };
}
