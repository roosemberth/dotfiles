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
        accounts = flip mapAttrs emailAccounts (_: secretCfg: let
          accountCfg = filterAttrs (n: _: n != "passwordPath") secretCfg;
        in accountCfg // {
          passwordCommand =
            "${pkgs.pass}/bin/pass show ${secretCfg.passwordPath}";
        });
        maildirBasePath = ".local/var/mail";
      };
      home.packages = with pkgs;
        [ gnupg mailcap pass-otp taskwarrior timewarrior ];
      home.sessionVariables = rec {
        PASSWORD_STORE_DIR = "${userCfg.xdg.dataHome}/pass";
        GNUPGHOME = "${userCfg.xdg.dataHome}/gnupg";
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
        defaultQuery = "search not (tag:killed or tag:deleted) and tag:inbox";
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
            "A" = "untag unread; toggletags inbox";
            "a" = "";
            "s" = "";
            "&" = "";
            "D" = "toggletags deleted; untag unread; untag inbox";
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
        extraConfig = ''
          auto_remove_unread = True
          envelope_html2txt = "pandoc -f html -t markdown"
          envelope_txt2html = "pandoc -f markdown -t html -s --self-contained"
          handle_mouse = True
          initial_command = ${defaultQuery}
          input_timeout = 0.3

          prefer_plaintext = True
          search.exclude_tags = "deleted"
          tabwidth = 2
          terminal_cmd = "alacritty -e"
          thread_indent_replies = 2

          ask_subject = True
          user_agent = "notmuch"
        '';
      };

      programs.mbsync.enable = true;
      programs.notmuch.enable = true;
      programs.notmuch.hooks.postNew = "afew --tag --new";
      programs.notmuch.hooks.preNew = "mbsync --all";
      programs.notmuch.new.tags = [ "new" ];

      home.file.".mailcap".source = util.fetchDotfile "etc/mailcap";

      xdg.configFile."task/taskrc".source = util.fetchDotfile "etc/taskrc";
    };
  };
}
