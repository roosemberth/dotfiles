{ config, pkgs, lib, secrets, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in
{
  options.roos.media.enable = mkEnableOption "Enable media suite.";

  config = mkIf config.roos.media.enable {
    roos.sConfigFn = userCfg: {
      home.file."Media/Music/.keep".text = ""; # Placeholder
      xdg.configFile."beets/config.yaml".source =
        util.renderDotfile "etc/beets/config.yaml" {
          configHome = userCfg.xdg.configHome;
          dataHome = userCfg.xdg.dataHome;
          musicDirectory = "${userCfg.home.homeDirectory}/Media/Music";
        };
      xdg.dataFile."beets/.keep".text = "";  # Placeholder
    };

    roos.gConfig = {
      home.packages = with pkgs; [
        ffmpeg-full
        freetube
        spotify
        tidal-hifi
        youtube-dl
      ];
      programs.mpv = {
        enable = true;
        config = {
          ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
          playlist-start = "auto";
          save-position-on-quit = true;
        };
        scripts = with pkgs.mpvScripts; [ quality-menu ];
      };
    };

    security.rtkit.enable = true;
  };
}
