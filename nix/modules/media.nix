{ config, pkgs, lib, secrets, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in
{
  options.roos.media.enable = mkEnableOption "Enable media suite.";

  config = mkIf config.roos.media.enable {
    roos.sConfigFn = userCfg: {
      home.packages = with pkgs; [ mopidy-roos beets ];

      home.file."Media/Music/.keep".text = ""; # Placeholder
      xdg.configFile."beets/config.yaml".source =
        util.renderDotfile "etc/beets/config.yaml" {
          configHome = userCfg.xdg.configHome;
          dataHome = userCfg.xdg.dataHome;
          musicDirectory = "${userCfg.home.homeDirectory}/Media/Music";
        };
      xdg.dataFile."beets/.keep".text = "";  # Placeholder

      # Mopidy configuration
      xdg.configFile."mopidy/mopidy.conf".source =
        let
          spotifySecret =
            name: secrets.users.roosemberth.volatile."spotify/${name}";
        in util.renderDotfile "etc/mopidy/mopidy.conf" {
          cacheHome = userCfg.xdg.cacheHome;
          configHome = userCfg.xdg.configHome;
          dataHome = userCfg.xdg.dataHome;
          musicDirectory = "${userCfg.home.homeDirectory}/Media/Music";
          mopidyClientId = spotifySecret "mopidy-spotify/client_id";
          mopidyClientSecret = spotifySecret "mopidy-spotify/client_secret";
          spotifyUserName = spotifySecret "username";
          spotifyPassword = spotifySecret "password";
        };
      xdg.dataFile."mopidy/Playlists/.keep".text = "";  # Placeholder
      systemd.user.services.mopidy =
      let
        configPath = "${userCfg.xdg.configHome}/mopidy/mopidy.conf";
      in {
        Unit.After = [ "network.target" "sound.target" ];
        Unit.Description = "Mopidy daemon";
        Unit.Conflicts = [ "mpd.service" ];
        Unit.PartOf = [ "basic.target" ];
        Service.ExecStart =
          "${pkgs.mopidy-roos}/bin/mopidy --config ${configPath}";
        Install.WantedBy = [ "basic.target" ];
      };

      # MPD configuration
      services.mpd.enable = true;
      services.mpd.musicDirectory =
        "${userCfg.home.homeDirectory}/Media/Music";
      services.mpd.playlistDirectory = "/tmp";
      # Disable autostart
      systemd.user.services.mpd.Install.WantedBy = lib.mkForce [];
      systemd.user.services.mpd.Unit.Conflicts = [ "mopidy.service" ];
    };

    roos.gConfig = {
      home.packages = with pkgs; [ youtube-dl ffmpeg-full spotify ];
      programs.mpv = {
        enable = true;
        config = {
          ytdl-format = "bestvideo[height<=?1080]+bestaudio/best";
          playlist-start = "auto";
          save-position-on-quit = true;
        };
        scripts = with pkgs.mpvScripts; [ youtube-quality ];
      };
    };

    security.rtkit.enable = true;
  };
}
