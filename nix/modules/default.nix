# Inspired from Infinisil's configuration repository @df9232c4 and my own
# modules systems prior to @02723409fb50dc52df92849383fa0c6a3572f987
{ lib, ... }: with lib;
let
  sourceHmEnv = {
    # Source home-manager environment
    config.environment.extraInit = ''
      if [ -d "/etc/profiles/per-user/$USER/etc/profile.d" ]; then
        . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };
  # FIXME: This should not be necessary, any system should be able to include
  # all modules and their definitions should do nothing if unused.
  standaloneModules = [
    ./lib.nix
    ./firewall.nix
  ];
in {
  _module.args = {
    roosModules = standaloneModules;
    networks.zkx = rec {
      dns = let
        removeCIDR = with lib; str: head (splitString "/" str);
      in {
        v4 = removeCIDR publicInternalAddresses.Minerva.v4;
        v6 = removeCIDR publicInternalAddresses.Minerva.v6;
      };
      publicInternalAddresses = {
        Heimdaalr.v4 = "10.13.255.101/24";
        Heimdaalr.v6 = "fd00:726f:6f73:101::1/56";
        Mimir.v4 = "10.13.255.35/24";
        Mimir.v6 = "fd00:726f:6f73:35::1/56";
        Minerva.v4 = "10.13.255.13/24";
        Minerva.v6 = "fd00:726f:6f73:13::1/56";
      };
    };
    users.roos = {
      ssh-public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSKHqDX+M61dKgmFJL1dlJQTvveSkcG99GWb3R2P5Tq argon2d-cbc-spf";
      hashedPassword = "$gy$j9T$zbhaIklVZtEL60nhD3phG1$enEdsSN2V831HzgdG8tWk.CCyRf2GEABXz7e0YM/4/4";
    };
  };

  # FIXME: Find a way to make this great (dynamic) again.
  # Restricted evaluation doesn't like getDir.
  imports = [
    sourceHmEnv
    ./agenda.nix
    ./backups.nix
    ./base.nix
    ./btrbk.nix
    ./container-host.nix
    ./dev.nix
    ./media.nix
    ./nginx-fileshare.nix
    ./steam.nix
    ./unfree.nix
    ./user-profiles/roosemberth.nix
    ./users.nix
    ./hyprland-session.nix
    ./sway-session.nix
    ./layout-trees.nix
    ./wireguard.nix
    ./wireguard-new.nix
  ] ++ standaloneModules;
}
