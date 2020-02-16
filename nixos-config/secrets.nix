{ lib }:

with lib;

if (builtins.getEnv("NIX_NO_SECRETS") != "") then builtins.trace "Building without secrets" { secretsAvailable = false; } else
let
  listFilesInDir = dir:
    mapAttrsToList (p: _: dir + "/" + p)
      (filterAttrs (path: type: type == "regular") (builtins.readDir dir));
  readSecretPath = path: strings.fileContents (toString ./secrets + "/" + path);
  mkMachine = givenName:
    let hostname_l = strings.toLower givenName;
    in {
      hostInitrdRSAKey = ./secrets + "/machines/${hostname_l}/ssh-keys/initramfs";
      wireguardKeys = wireguardSecrets hostname_l;
    };
  wireguardSecrets = hostname_l:
    { private = readSecretPath "machines/${hostname_l}/wireguard-keys/private";
      public = readSecretPath "machines/${hostname_l}/wireguard-keys/public";
    };
  roosemberth = import ./secrets/users/roosemberth.nix { inherit lib; };
in {
  secretsAvailable = true;
  machines = recursiveUpdate
      (listToAttrs (map (m: { name = m; value = mkMachine m; })
        ["Azulejo" "Dellingr" "Heimdaalr" "Heisenberg" "Hellendaal" "Lappie" "Triglav"]))
      { # Azulejo.sdasd.dd = 5;  # This will add attr `sdasd.dd` to `Azulejo`
      };
  adminPubKeys = [ roosemberth.sshPubKey ];
  users = {
    inherit roosemberth;
  };
  network = import ./secrets/network.nix;
}
