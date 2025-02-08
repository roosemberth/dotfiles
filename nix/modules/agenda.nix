{ config, pkgs, lib, secrets, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.agenda.enable = mkEnableOption "Organizational stuff...";

  config = mkIf config.roos.agenda.enable {
    roos.sConfigFn = userCfg: {
      home.packages = with pkgs; let
        pass' = pass.withExtensions (p: with p; [ pass-otp ]);
      in [
        mailcap pass' w3m xdg-utils
        timewarrior gnome-keyring gcr pkgs.libsecret
      ];
      home.sessionVariables = rec {
        PASSWORD_STORE_DIR = "${userCfg.xdg.dataHome}/pass";
        GNUPGHOME = "${userCfg.xdg.dataHome}/gnupg";
        TIMEWARRIORDB = "${userCfg.xdg.dataHome}/timewarrior";
      };
    };

    roos.gConfig = {
      home.packages = with pkgs; [ evince ];
      xdg.mimeApps.associations.added = {
        "application/pdf" = ["org.gnome.Evince.desktop"];
        "image/png" = ["eog.desktop"];
      };
    };
  };
}
