{ config, pkgs, lib, ... }: with lib;
{
  options.roos.game-fixes.enable = mkEnableOption "Enable various fixes for games";

  config = mkIf config.roos.game-fixes.enable {
    services.pipewire.extraConfig = {
      pipewire-pulse."crackly-games" = {
        "pulse.rules" = [{
          matches = [{ "application.name" = "Subnautica.exe"; }];
          actions.update-props = {
            "pulse.min.req" = "2048/48000";
            "pulse.min.quantum" = "2048/48000";
          };
        }];
      };
    };
  };
}
