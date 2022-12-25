{ lib, _modinjector ? false, ... }:
with lib; assert (assertMsg _modinjector
                  "The secrets module should not be called directly.");
let
  admins = import ./secrets/users/admins.nix { inherit lib; };
in recursiveUpdate (rec {
  adminPubKeys = admins.authorizedPublicKeys;
  users = import ./secrets/users/users.nix { inherit lib; };
}) {}
