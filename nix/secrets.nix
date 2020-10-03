{ lib, _secrets_loaded_by_injector ? false, ... }:
with lib; assert (assertMsg _secrets_loaded_by_injector
                  "The secrets module should not be called directly.");
let
  readSecretPath = path: strings.fileContents (toString ./secrets + "/" + path);
  wireguardSecrets = host:
    { private = readSecretPath "machines/${host}/wireguard-keys/private";
      public = readSecretPath "machines/${host}/wireguard-keys/public";
    };
  admins = import ./secrets/users/admins.nix { inherit lib; };
  opaque = import ./secrets/opaque.nix { inherit lib; };
in recursiveUpdate ({
  adminPubKeys = admins.authorizedPublicKeys;

  forHost = hostname: recursiveUpdate ({
    keys = {
      ssh-initramfs = let
        path = ./secrets + "/machines/${hostname}/ssh-initramfs-keys/";
        isPrivateKey = name: type: type == "regular" && ! strings.hasSuffix ".pub" name;
        keys = attrNames (filterAttrs isPrivateKey (builtins.readDir path));
      in lib.genAttrs keys (key: path + "/${key}");
      wireguard = wireguardSecrets hostname;
    };
  }) (attrByPath [hostname] {} {
    # Azulejo.foo.bar = 5;  # This will add `foo.bar` for Azulejo
  });

  network = import ./secrets/network.nix {};
  users.roosemberth = import ./secrets/users/roosemberth.nix { inherit lib; };
  secretsAvailable = true;
}) opaque.secrets
