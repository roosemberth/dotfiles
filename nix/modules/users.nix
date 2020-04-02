# Inspired from Infinisil's configuration repository @df9232c4
{ config, pkgs, lib, options, ... }: with lib;
let
  home-manager =
    let try = builtins.tryEval <home-manager>;
    in if try.success then try.value
    else builtins.trace "Using pinned version for home manager" (
      builtins.fetchGit {
        url = "https://github.com/rycee/home-manager.git";
        rev = "dd93c300bbd951776e546fdc251274cc8a184844";
      });
  userProfileType = with types; submodule {
    options = let
      optionType = mkOption {
        type = listOf str;
        example = [ "paul" "john" ];
        default = [];
      };
    in {
      reduced = optionType // { description = ''
        User profiles with reduced configuration enabled.
      ''; };
      simple = optionType // { description = ''
        User profiles with simple configuration enabled.
      ''; };
      graphical = optionType // { description = ''
        User profiles with graphical configuration enabled.
      ''; };
    };
  };
in {
  imports = [ (home-manager + "/nixos") ];

  options.roos = {
    dotfilesPath = mkOption {
      type = with types; nullOr path;
      default = null;
      description = ''
        Path to external dotfiles repository. If defined, applications and
        services requiring files from such repository will be enabled.
      '';
    };

    impureDotfiles = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, derivations requiring files in the dotfiles repository
        will use a symlink in the nix store to the dotfiles repository.
        This is intended for debugging and should generally be set to false.
        When false, paths from the dotfiles will be copied into the nix store.
      '';
    };

    user-profiles = mkOption {
      type = userProfileType;
      default = { reduced = []; simple = []; graphical = []; };
      description = "User profiles enabled in this system.";
    };

    rConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with reduced
        configuration enabled.
      '';
    };

    rConfigFn = mkOption {
      #type = options.home-manager.users.type.functor.wrapped;
      default = _: {};
      description = ''
        Function returning a Home-manager configuration to be used in
        user-profiles with reduced configuration enabled.
        The function will be called with the user configuration as
        argument (i.e. `config.home-manager.users.$${user}`).
      '';
    };

    sConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with simple
        configuration enabled; in particular without a graphical session.
      '';
    };

    sConfigFn = mkOption {
      #type = options.home-manager.users.type.functor.wrapped;
      default = _: {};
      description = ''
        Function returning a Home-manager configuration to be used in
        user-profiles with simple configuration enabled; in particular
        without a graphical session.
        The function will be called with the user configuration as
        argument (i.e. `config.home-manager.users.$${user}`).
      '';
    };

    gConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with graphical
        configuration enabled. This will in all cases exclude the root user.
      '';
    };

    gConfigFn = mkOption {
      #type = options.home-manager.users.type.functor.wrapped;
      default = _: {};
      description = ''
        Function returning a Home-manager configuration to be used in
        user-profiles with graphical configuration enabled.
        This will in all cases exclude the root user.
        The function will be called with the user configuration as
        argument (i.e. `config.home-manager.users.$${user}`).
      '';
    };
  };

  config = let
    mkUserCfgs = users: cfgFilter: let
      cfgs = cfgFilter options.roos;
    in mkMerge (flip crossLists [users cfgs] (user: cfg: {
      ${user} = mkAliasDefinitions cfg;
    }));
    callUserCfgFns = users: cfgFilter: let
      cfgFns = cfgFilter config.roos;
    in mkMerge (flip crossLists [users cfgFns] (user: cfgFn: {
      # Note: We can get away with directly merging the submodule because
      # options with default values have already been rendered by home-manager
      # (see mkAliasDefinitions use above).
      ${user} = (cfgFn config.home-manager.users.${user});
    }));
    userCfgs = with config.roos.user-profiles; {
      usersWithReducedConfigurations = mkMerge [
        (mkUserCfgs reduced (c: with c; [rConfig]))
        (callUserCfgFns reduced (c: with c; [rConfigFn]))
      ];
      usersWithSimpleConfigurations = mkMerge [
        (mkUserCfgs simple  (c: with c; [rConfig sConfig]))
        (callUserCfgFns simple  (c: with c; [rConfigFn sConfigFn]))
      ];
      usersWithGraphicalConfigurations = let
        users = (filter (u: u != "root") graphical);
      in mkMerge [
        (mkUserCfgs users (c: with c; [rConfig sConfig gConfig]))
        (callUserCfgFns users (c: with c; [rConfigFn sConfigFn gConfigFn]))
      ];
    };
  in {
    home-manager.users = mkMerge (attrValues userCfgs);
    # See <https://github.com/rycee/home-manager/issues/1120>.
    # home-manager.useUserPackages = true;
    home-manager.verbose = true;

    # Source home-manager environment
    environment.extraInit = concatMapStringsSep "\n" (user: let
      homedir = config.users.users.${user}.home;
    in ''
      if [ "$(id -un)" = "${user}" ]; then
        . "${homedir}/.nix-profile/etc/profile.d/hm-session-vars.sh"
      fi
    '') (flatten (attrValues config.roos.user-profiles));

    assertions = map (user: {
      assertion = builtins.hasAttr user config.users.users;
      message = "The main user ${user} has to exist";
    }) (flatten (attrValues config.roos.user-profiles));
  };
}
