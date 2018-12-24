{ config, pkgs, lib, ... }:
{
  imports = [ ./Triglav.nix ];
  networking.hostName = lib.mkForce "Triglav-ccc";
  networking.extraHosts = lib.mkForce ''
    127.0.0.1 Triglav-ccc triglav-ccc.roaming.orbstheorem.ch
    5.2.74.181 Hellendaal hellendaal.orbstheorem.ch
    46.101.112.218 Heisenberg heisenberg.orbstheorem.ch
    95.183.51.23 Dellingr dellingr.orbstheorem.ch
  '';
  users.extraUsers.roosemberth.hashedPassword =
    lib.mkForce "$6$FRRhyJnGdPTm5UM2$cPFoqHq9Av.EFIrJ1c5Poj7quICfGeu7iWTkXhJcsNBed94Gl5ZKgo8YRFcLcd3FWm2pEuspBSHvi6nCxTCm60";

  boot.loader.grub.splashImage =
    "${pkgs.nixos-artwork.wallpapers.simple-red}/share/artwork/gnome/nix-wallpaper-simple-red.png";
}
