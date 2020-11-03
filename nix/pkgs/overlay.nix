final: prev: {
  mfgtools = final.callPackage ./mfgtools { };
  ensure-nodatacow-btrfs-subvolume =
    final.callPackage ./ensure-nodatacow-btrfs-subvolume.nix { };
}
