{ lib, _modinjector ? false, ... }:
with lib; assert (assertMsg _modinjector
                  "The secrets module should not be called directly."); {
  users = import ./secrets/users/users.nix { inherit lib; };
}
