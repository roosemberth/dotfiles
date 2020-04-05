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
          passwordCommand = "${pkgs.pass}/bin/pass show ${secretCfg.passwordPath}";
        });
        maildirBasePath = ".local/var/mail";
      };
      home.packages = with pkgs; [ gnupg mailcap taskwarrior timewarrior ];

      programs.afew.enable = true;
      programs.alot.enable = true;
      programs.mbsync.enable = true;
      programs.notmuch.enable = true;
      programs.notmuch.hooks.postNew = "afew --tag --new";
      programs.notmuch.hooks.preNew = "mbsync --all";

      xdg.configFile."task/taskrc".source = util.fetchDotfile "etc/taskrc";
    };
  };
}
