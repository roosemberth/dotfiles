{ config, pkgs, lib, secrets, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
  mopidy' = with pkgs; buildEnv {
    name = "mopidy-with-extensions-${mopidy.version}";
    paths = lib.closePropagation (with pkgs.mopidyPackages; [
      mopidy-spotify mopidy-iris mopidy-mpd
    ]);
    pathsToLink = [ "/${python3.sitePackages}" ];
    buildInputs = [ makeWrapper ];
    postBuild = ''
      makeWrapper ${mopidy}/bin/mopidy $out/bin/mopidy \
      --prefix PYTHONPATH : $out/${python3.sitePackages}
    '';
  };
in
{
  options.roos.media.enable = mkEnableOption "Enable media suite.";

  config = mkIf config.roos.media.enable {
    roos.sConfigFn = userCfg: {
      home.packages = with pkgs; [ mopidy' beets ];

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
        Service.ExecStart = "${mopidy'}/bin/mopidy --config ${configPath}";
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
      home.packages = with pkgs; [ mpv youtube-dl ffmpeg-full ];
    };
  };
}
