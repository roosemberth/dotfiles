# Inspired from Infinisil's configuration repository @df9232c4 and my own
# modules systems prior to @02723409fb50dc52df92849383fa0c6a3572f987
{ lib, ... }: with lib;
let
  sourceHmEnv = {
    # Source home-manager environment
    config.environment.extraInit = ''
      if [ -d "$HOME/.nix-profile/etc/profile.d" ]; then
        . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '';
  };
in {
  _module.args = {
    secrets = import ../secrets.nix { inherit lib; _modinjector = true; };
  };

  # FIXME: Find a way to make this great (dynamic) again.
  # Restricted evaluation doesn't like getDir.
  imports = [
    sourceHmEnv
    ./agenda.nix
    ./base.nix
    ./dev.nix
    ./eivd.nix
    ./keyring.nix
    ./media.nix
    ./overlays.nix
    ./steam.nix
    ./sway.nix
    ./unfree.nix
    ./user-profiles/roosemberth.nix
    ./users.nix
    ./wireguard.nix
  ];
}
