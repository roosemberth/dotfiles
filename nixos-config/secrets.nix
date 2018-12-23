{ lib }:

with lib;

if (builtins.getEnv("NIX_NO_SECRETS") != "") then builtins.trace "Building without secrets" { secretsAvailable = false; } else
let
  listFilesInDir = dir:
    mapAttrsToList (p: _: dir + "/" + p)
      (filterAttrs (path: type: type == "regular") (builtins.readDir dir));
  mkMachine = givenName:
    let machine = strings.toLower givenName;
    in {
      hostInitrdRSAKey = (toString ./secrets/machines) + "/" + machine + "/ssh-keys/initramfs";
      wireguardKeys = wireguardSecrets machine;
    };
  readSecretPath = path: strings.fileContents (toString ./secrets + "/" + path);
  wireguardSecrets = hostname:
    { private = readSecretPath "machines/${hostname}/wireguard-keys/private";
      public = readSecretPath "machines/${hostname}/wireguard-keys/public";
    };
in {
  secretsAvailable = true;
  machines = recursiveUpdate
      (listToAttrs (map (m: { name = m; value = mkMachine m; })
        ["Azulejo" "Dellingr" "Heimdaalr" "Heisenberg" "Hellendaal" "Lappie" "Triglav"]))
      { # Azulejo.sdasd.dd = 5;  # This will add attr `sdasd.dd` to `Azulejo`
      };
  adminPubKeys = [ (readFile secrets/admins/ssh-keys/roosemberth.pub) ];
  users = {
    roosemberth = {
      sshPubKey = [ (readFile secrets/admins/ssh-keys/roosemberth.pub) ];
    };
  };
}
