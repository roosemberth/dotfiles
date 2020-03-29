{ lib, hostname, _called_by_injector ? false }:
with lib; assert (assertMsg _called_by_injector
                  "The secrets module should not be called directly.");
let
  readSecretPath = path: strings.fileContents (toString ./secrets + "/" + path);
  wireguardSecrets = host:
    { private = readSecretPath "machines/${host}/wireguard-keys/private";
      public = readSecretPath "machines/${host}/wireguard-keys/public";
    };
  admins = import ./secrets/users/admins.nix { inherit lib; };
  opaque = import ./secrets/opaque.nix { inherit lib; };
  maybeAttrset = key: def: set: if hasAttr key set then getAttr key set else def;
in recursiveUpdate ({
  adminPubKeys = admins.authorizedPublicKeys;

  machine = recursiveUpdate ({
    keys = {
      sshInitramfsHost = ./secrets + "/machines/${hostname}/ssh-keys/initramfs";
      wireguard = wireguardSecrets hostname;
    };
  }) (maybeAttrset hostname {} {
    # Azulejo.foo.bar = 5;  # This will add `foo.bar` for Azulejo
  });

  network = import ./secrets/network.nix { inherit lib; };

  users = {
    roosemberth = import ./secrets/users/roosemberth.nix { inherit lib; };
  };

  secretsAvailable = true;
}) (maybeAttrset hostname {} opaque.secrets)
