{ config, pkgs, lib, ... }: with lib; let
  cfg = config.roos.media;
in {
  options.roos.media.enable =
    mkEnableOption "Roos' config for multimedia facililities";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ playerctl ];

    roos.actions = let
      playerctl = "${pkgs.playerctl}/bin/playerctl";
    in {
      "player:play-pause" = "${playerctl} play-pause";
      "player:prev"       = "${playerctl} previous";
      "player:next"       = "${playerctl} next";
    };
  };
}
