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
in {
  _module.args = {
    secrets = import ../secrets.nix { inherit lib; _modinjector = true; };
  };

  # FIXME: Find a way to make this great (dynamic) again.
  # Restricted evaluation doesn't like getDir.
  imports = [
    sourceHmEnv
    # FIXME: This is horrible, I should find a way to remove it
    ({ secrets, ... }: { home-manager.extraSpecialArgs.secrets = secrets; })
    ./agenda.nix
    ./base.nix
    ./btrbk.nix
    ./container-host.nix
    ./dev.nix
    ./keyring.nix
    ./media.nix
    ./nginx-fileshare.nix
    ./steam.nix
    ./unfree.nix
    ./user-profiles/roosemberth.nix
    ./users.nix
    ./sway-session.nix
    ./wireguard.nix
    ./wireguard-new.nix
  ];
}
