{ config, pkgs, lib, secrets, ... }: with lib;
{
  options.roos.eivd.enable =
    mkEnableOption "Stuff required during my studies at HEIG-VD";

  config = mkIf config.roos.eivd.enable {
    networking.bridges.containers.interfaces = [];
    networking.bridges.containers.rstp = true;

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
  };
}
