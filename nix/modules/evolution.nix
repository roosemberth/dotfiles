{ config, pkgs, lib, ... }: with lib;
{
  options.roos.evolution.enable = mkEnableOption "Evolution mail and calendar";

  config = mkIf config.roos.evolution.enable {
    programs.evolution.enable = true;
    roos.gConfig = {
      home.packages = with pkgs; [ gnome-online-accounts-gtk ];
    };
  };
}
