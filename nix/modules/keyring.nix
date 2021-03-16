# This module manages user keyrings.
{ config, pkgs, lib, hmlib, secrets, ... }: with lib;
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
        in hmlib.dag.entryAfter [ "linkGeneration" "installPackages" ] ''
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
