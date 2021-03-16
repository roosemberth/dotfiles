{ config, pkgs, lib, secrets, ... }: with lib;
let
  cfg = config.services.email-gateway;
  username = config.home.username;
  emailAccounts = secrets.users.${username}.emailAccounts or {};
  passFromKeyring = name: "${pkgs.pass-keyrings}/bin/lookup-keyring "
    + "${cfg.password-source.keyring-name} ${name}";
  passFromLibSecret = name: "${pkgs.gnome3.libsecret}/bin/secret-tool lookup "
    + "${cfg.password-source.libsecret-set} ${name}";
  passFn = if cfg.password-source.keyring-name != null
           then passFromKeyring else passFromLibSecret;
in {
  options.services.email-gateway = {
    enable = mkEnableOption "Retrieve classify and relay emails periodically.";
    frequency = mkOption {
      type = with types; nullOr str;
      default = "*:0/5";
      description = ''
        How often to run mbsync. If 'null' no timers will be installed.
        This value is passed to the systemd timer configuration as the
        onCalendar option. See
        <citerefentry>
          <refentrytitle>systemd.time</refentrytitle>
          <manvolnum>7</manvolnum>
        </citerefentry>
        for more information about the format.
      '';
    };
    password-source.keyring-name = mkOption {
      type = with types; nullOr str;
      description = ''
        If set, the name of the user keyring to query the password from.
        i.e. 'lookup-keyring keyring-name account-name'.
      '';
    };
    password-source.libsecret-set = mkOption {
      type = with types; nullOr str;
      description = ''
        If set, the name of the secret-tool attibute where the account passwords
        can be found. i.e. 'lookup-keyring keyring-name account-name'.
      '';
    };
  };

  config = mkIf (cfg.enable && emailAccounts != {}) {
    assertions = [{
      assertion = with cfg.password-source;
        keyring-name != null || libsecret-set != null;
      message = "At least one password-source should be defined.";
    }];

    accounts.email = {
      accounts = mapAttrs (accName: accDetails: lib.recursiveUpdate accDetails {
        alot.sendMailCommand = "msmtp --account=${accName} -t";
        passwordCommand = passFn accName;
      }) emailAccounts;
      maildirBasePath = ".local/var/mail";
    };

    systemd.user = let
      systemdCfgs = (map (accName: {
        services."mbsync@${accName}" = {
          Unit.Before = [ "mbsync.service" ];
          Unit.Description = "Mailbox synchronization for account ${accName}";
          # Required by the lookup-keyring command.
          Service.Environment = "XDG_DATA_HOME=${config.xdg.dataHome}";
          Service.ExecStart = "${pkgs.isync}/bin/mbsync ${accName}";
          Service.Type = "oneshot";
          Install.WantedBy = [ "mbsync.service" ];
        };
      }) (attrNames emailAccounts)) ++ [{
        services."mbsync" = {
          Unit.Description = "Mailbox synchronization";
          Service.ExecStart = "${pkgs.coreutils}/bin/true";
          Service.Type = "oneshot";
        };
        timers."mbsync" = mkIf (cfg.frequency != null) {
          Unit.Description = "Mailbox synchronization";
          Install.WantedBy = [ "timers.target" ];
          Timer.OnCalendar = cfg.frequency;
          Timer.Unit = "mbsync.service";
        };
        services."notmuch" = {
          Unit.After = [ "mbsync.service" ];
          Unit.Description = "Index new email";
          Service.ExecStart = "${pkgs.notmuch}/bin/notmuch new";
          Service.Type = "oneshot";
          Install.WantedBy = [ "mbsync.service" ];
        };
        services."afew" = {
          Unit.After = [ "notmuch.service" ];
          Unit.Description = "Generate tags for new email";
          Service.ExecStart = "${pkgs.afew}/bin/afew --tag --new";
          Service.Type = "oneshot";
          Install.WantedBy = [ "mbsync.service" ];
        };
      }];
    in foldl (a: b: recursiveUpdate a b) {} systemdCfgs;

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
    programs.mbsync.enable = true;
    programs.msmtp.enable = true;
    programs.notmuch.enable = true;
    programs.notmuch.new.tags = [ "new" ];
  };
}
