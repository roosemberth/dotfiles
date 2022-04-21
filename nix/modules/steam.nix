{ config, pkgs, lib, ... }: with lib;
{
  options.roos.steam.enable = mkEnableOption "Enable steam support";

  config = mkIf config.roos.steam.enable {
    programs.steam.enable = true;
    nixpkgs.config.packageOverrides = pkgs: {
      steam = pkgs.steam.override {
        extraProfile = "export SDL_VIDEODRIVER=x11";
      };
    };
  };
}
