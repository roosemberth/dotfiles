# This module manages user keyrings.
{ config, pkgs, lib, secrets, ... }: with lib;
{
  options.roos.user-keyrings = with types; mkOption {
    description = "User keyring submodules.";
    default = {};
    type = attrsOf (submodule {
      options.keyrings = mkOption {
        default = [];
        type = listOf (submodule {
          options.name = mkOption {
            description = "Name of the keyring";
            type = str;
          };
          options.key = mkOption {
            description = "Path to the file containing the key";
            type = path;
          };
          options.archive = mkOption {
            description = "Path to a zip-compressed password store dir";
            type = path;
          };
        });
      };
    });
  };

  config = {
    home-manager.users = mapAttrs (user: {keyrings}:
      let
        cfg = config.home-manager.users."${user}";
        pass-keyrings = pkgs.writeShellScriptBin "lookup-keyring" ''
          #!/bin/sh
          # (C) Roosembert Palacios, 2020

          # This program is free software: you can redistribute it and/or modify
          # it under the terms of the GNU General Public License as published by
          # the Free Software Foundation, either version 3 of the License, or
          # (at your option) any later version.

          # Exit codes
          E_SUCCESS=0
          E_USER=1
          E_PREREQ=127

          die()
          {
              retval="$1"; shift
              if [ $# -eq 0 ]; then
                  cat <&0 >&2
              else
                  printf "$@" >&2; echo >&2
              fi
              if [ "$retval" = $E_USER ]; then
                  printf "Run with --help for more information.\n" >&2
              fi
              exit "$retval"
          }

          usage()
          {
              cat <<-EOF
          			$(basename "$0"): Lookup a password in the specified keyring.
          			A keyring with the specified name must exist under
          			$XDG_DATA_HOME/keyrings/<keyring>.

          			A keyring is composed of a 'gpg' and a 'pass' folders.
          			The 'pass' folder will be used as PASSWORD_STORE_DIR and the
          			'gpg' folder as GNUPGHOME. The password will be then looked-up
          			using the 'pass' command.

          			Usage:
          			$(basename "$0") <-h|--help>
          			$(basename "$0") <keyring> <password-name>
          		EOF
          }

          if [ -z "$XDG_DATA_HOME" ]; then
            die $E_PREREQ "The XDG_DATA_HOME envvar must be set."
          fi

          KEYRING=
          PASSWORD=
          while [ $# -gt 0 ]; do
              opt="$1"; shift
              case "$opt" in
                  (-h|--help) usage; exit ;;
                  (-*) die $E_USER 'Unknown option: %s' "$opt" ;;
                  (*)
                    if [ -z "$KEYRING" ]; then
                      KEYRING="$XDG_DATA_HOME/keyrings/$opt"
                    elif [ -z "$PASSWORD" ]; then
                      PASSWORD="$opt"
                    else
                      die $E_USER 'Trailing argument: %s' "$opt"
                    fi
                    ;;
              esac
          done

          if [ -z "$KEYRING" ]; then
            die $E_USER "A keyring must be specified."
          fi
          if [ -z "$PASSWORD" ]; then
            die $E_USER "A password to lookup must be specified."
          fi

          #--------------------------------------------------------
          set -e

          if ! [ -d "$KEYRING/gpg" ]; then
            die $E_USER "Could not find the keyring's GNUPG installation."
          fi
          if ! [ -d "$KEYRING/pass" ]; then
            die $E_USER "Could not find the keyring's pass directory."
          fi

          exec env GNUPGHOME="$KEYRING/gpg" PASSWORD_STORE_DIR="$KEYRING/pass" \
            ${pkgs.pass}/bin/pass show "$PASSWORD"
        '';
        keyringFor = name: archive: pkgs.runCommand "keyring-${name}" {}
          "${pkgs.unzip}/bin/unzip ${archive} >/dev/null; mv ${name} $out";
      in mkIf (keyrings != []) {
        xdg.dataFile = foldl' (v: {name, key, archive}: v // {
          "keyrings/${name}/key".source = key;
          "keyrings/${name}/pass".source = keyringFor name archive;
        }) {} keyrings;

        home.packages = with pkgs; [ gnupg pass-keyrings ];

        home.activation.keyrings =
        let
          keyring-names = map ({name, ...}: name) keyrings;
        in lib.hm.dag.entryAfter [ "linkGeneration" "installPackages" ] ''
          # Import GPG keys and extract password store for each keyring
          for k in ${escapeShellArgs keyring-names}; do
            mkdir -p "${cfg.xdg.dataHome}/keyrings/$k/gpg"
            chmod 700 "${cfg.xdg.dataHome}/keyrings/$k/gpg"
            GNUPGHOME="${cfg.xdg.dataHome}/keyrings/$k/gpg" \
              gpg --import "${cfg.xdg.dataHome}/keyrings/$k/key"
          done
        '';

        xdg.enable = true;
      }
    ) config.roos.user-keyrings;
  };
}
