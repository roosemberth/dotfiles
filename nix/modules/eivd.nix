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
        maven
        openjdk
      ];
    };

    roos.gConfig = let
      teams = with pkgs;
        assert (assertMsg config.programs.firejail.enable
          "firejail is required to run MS teams");
        stdenv.mkDerivation {
          name = "jailed-MS-teams";
          # Can't use makeWrapper since firejail should be called from PATH
          buildCommand = ''
            mkdir -p "$out/bin" "$out/share/applications"
            echo "#! /bin/sh -e" > "$out/bin/teams"
            echo exec firejail --overlay-named=teams \
              '"${pkgs.teams}/bin/teams"' >> "$out/bin/teams"
            chmod +x "$out/bin/teams"

            cp "${pkgs.teams}/share/applications/teams.desktop" \
              "$out/share/applications/teams.desktop"
          '';
          preferLocalBuild = true;
          allowSubstitutes = false;
        };
    in {
      home.packages = [ teams ];
      xdg.mimeApps.defaultApplications = {
        "x-scheme-handler/msteams" = ["teams.desktop"];
      };
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
