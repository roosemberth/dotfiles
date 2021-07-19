# Compatibility layer to allow building a system derivation on a vm.
# This is needed because not all config options are compatible with a VM.
#
# More importantly, this file should not be imported from the system
# derivation.
{ lib, ... }: with lib;
{
  config = {
    # Fails assertion because of missing btrfs filesystems
    services.btrfs.autoScrub.enable = mkVMOverride false;

    # Avoid mishaphs
    roos.wireguard.enable = mkVMOverride false;
  };
}
