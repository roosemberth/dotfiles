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
        timewarrior gnome.gnome-keyring gcr pkgs.libsecret
      ];
      home.sessionVariables = rec {
        PASSWORD_STORE_DIR = "${userCfg.xdg.dataHome}/pass";
        GNUPGHOME = "${userCfg.xdg.dataHome}/gnupg";
        TASKRC = "${userCfg.xdg.configHome}/task/taskrc";
        TASKDATA = "${userCfg.xdg.dataHome}/task";
        TIMEWARRIORDB = "${userCfg.xdg.dataHome}/timewarrior";
      };

      programs.taskwarrior.enable = true;
      programs.taskwarrior.config = {
        dateformat = "Y-M-DTH:N";
        default.command = "list";

        context.gnu = "project:GNUGen";
        context.agep = "project:AGEPoly";
        context.bity = "project:Bity";
        context.epfl = "project:EPFL";

        color.tag.nohl = "blue";

        report.list.columns = "id,project,tags,priority,start.active,description,due,due.remaining";
        report.list.labels = "ID,Proj,Tags,Pri,A,Description,Due,";
      };

      # Should make a module someday...
      xdg.dataFile."task/hooks/on-modify.timewarrior".source =
        util.fetchDotfile "etc/task/on-modify.timewarrior";
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
