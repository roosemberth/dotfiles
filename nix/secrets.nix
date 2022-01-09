{ lib, _modinjector ? false, ... }:
with lib; assert (assertMsg _modinjector
                  "The secrets module should not be called directly.");
let
  readSecretPath = path: strings.fileContents (toString ./secrets + "/" + path);
  wireguardSecrets = host:
    { public = readSecretPath "machines/${host}/wireguard-keys/public"; };
  admins = import ./secrets/users/admins.nix { inherit lib; };
  opaque = import ./secrets/opaque.nix { inherit lib; };

  keyring-names =
  let files = builtins.readDir ./secrets/keyrings;
      keys = attrNames (filterAttrs (name: _: hasSuffix ".asc" name) files);
  in map (removeSuffix ".asc") keys;
in recursiveUpdate ({
  adminPubKeys = admins.authorizedPublicKeys;

  forHost = hostname: recursiveUpdate ({
    keys.wireguard = wireguardSecrets hostname;
    pubkeys.sshFor =
      purpose: readSecretPath "machines/${hostname}/ssh-keys/${purpose}.pub";
  }) (attrByPath [hostname] {} opaque.secrets.hosts);

  network = import ./secrets/network.nix {};
  users = import ./secrets/users/users.nix { inherit lib; };
  keyrings = genAttrs keyring-names (name: {
    inherit name;
    key = ./. + "/secrets/keyrings/${name}.asc";
    archive = ./. + "/secrets/keyrings/${name}.zip";
  });
}) opaque.secrets
