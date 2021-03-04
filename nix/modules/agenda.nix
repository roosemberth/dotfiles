{ config, pkgs, lib, secrets, ... }: with lib;
let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.agenda.enable = mkEnableOption "Organizational stuff...";

  config = mkIf config.roos.agenda.enable {
    roos.sConfigFn = userCfg: {
      accounts.email = let
        username = userCfg.home.username;
        emailAccounts = secrets.users.${username}.emailAccounts;
      in mkIf (hasAttrByPath [username "emailAccounts"] secrets.users) {
        accounts = flip mapAttrs emailAccounts (
          accName: secretCfg: lib.recursiveUpdate secretCfg {
          alot.sendMailCommand = "msmtp --account=${accName} -t";
          passwordCommand =
            "${pkgs.gnome3.libsecret}/bin/secret-tool lookup mbsync ${accName}";
        });
        maildirBasePath = ".local/var/mail";
      };
      home.packages = with pkgs;
        let gnome-keyring = # Install gnome-keyring without suid-wrapper
              assert lib.versionOlder gnome3.gnome-keyring.version "3.36.1";
              gnome3.gnome-keyring.overrideAttrs(_:{postFixup="";});
        in [
        gnupg mailcap pass-otp w3m xdg_utils
        taskwarrior timewarrior python3Packages.bugwarrior
        gnome-keyring gcr gnome3.libsecret
      ];
      home.sessionVariables = rec {
        PASSWORD_STORE_DIR = "${userCfg.xdg.dataHome}/pass";
        GNUPGHOME = "${userCfg.xdg.dataHome}/gnupg";
        TASKRC = "${userCfg.xdg.configHome}/task/taskrc";
        TASKDATA = "${userCfg.xdg.dataHome}/task";
        TIMEWARRIORDB = "${userCfg.xdg.dataHome}/timewarrior";
      };

      programs.afew.enable = true;
      programs.afew.extraConfig = ''
        [FolderNameFilter]
        # Intentionally lie to the filter to prevent it from flattening
        # the directory structure
        maildir_separator = .
        [KillThreadsFilter]
        [ListMailsFilter]
        [SpamFilter]
        [InboxFilter]

      '';

      programs.alot = let
        defaultQuery = "search tag:force_show or (not (tag:killed or tag:deleted) and (tag:inbox or tag:draft))";
        moveNextIncl = query: "move next ${query}; move previous ${query}";
      in {
        enable = true;
        bindings = {
          global = {
            "I" = ""; # empty string to unbind default
            "U" = "";
            "." = "";
            "i" = defaultQuery;
            "u" = "search tag:unread";
            "tab" = "bnext; refresh";
            "d" = "bclose; move up; move down";
            "shift tab" = "taglist";
          };
          search = {
            "w" = "move up";
            " " = "untag unread; move down";
            "r" = "shellescape 'notmuch new'";
            "e" = ''select; ${moveNextIncl "tag:unread"}'';
            "enter" = ''select; ${moveNextIncl "tag:unread"}'';
            "!" = "untag unread; tag flagged; fold; move down";
            "A" = "tag force_show; untag unread, inbox, force_show";
            "a" = "";
            "s" = "";
            "&" = "";
            "D" = "tag force_show; tag deleted; untag unread, inbox, force_show";
          };
          thread = {
            "Control r" = "reply --all";
            "R" = "reply --all";
            "w" = "untag unread; fold; move down";
            " " = "move page down";
            "!" = "tag flagged; untag unread; fold; move down";
            "A" = "untag inbox; untag unread; fold; move down";
            "D" = "tag killed; untag unread; untag inbox; fold; move down";
            "@" = ''refresh; unfold tag:unread; ${moveNextIncl "tag:unread"}''; # instead of simple refresh
            "u" = "pipeto ${pkgs.urlscan}/bin/urlscan";
          };
        };
        settings = {
          ask_subject = true;
          envelope_html2txt = "pandoc -f html -t markdown";
          envelope_txt2html = "pandoc -f markdown -t html -s --self-contained";
          initial_command = defaultQuery;
          input_timeout = 0.3;
          "search.exclude_tags" = "deleted";
          tabwidth = 2;
          terminal_cmd = "alacritty -e";
          thread_indent_replies = 2;
          user_agent = "notmuch";
        };
      };

      programs.mbsync.enable = true;
      programs.msmtp.enable = true;
      programs.notmuch.enable = userCfg.accounts.email.accounts != {};
      programs.notmuch.hooks.postNew = "afew --tag --new";
      programs.notmuch.hooks.preNew = "mbsync --all";
      programs.notmuch.new.tags = [ "new" ];

      home.file.".mailcap".source = util.fetchDotfile "etc/mailcap";

      xdg.configFile."task/taskrc".source = util.fetchDotfile "etc/task/taskrc";
      # Should make a module someday...
      xdg.configFile."bugwarrior/bugwarriorrc".text =
        secrets.users.roosemberth.bugwarriorrc;
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
