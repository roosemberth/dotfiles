# Inspired from Infinisil's configuration repository @df9232c4
{ config, pkgs, lib, options, ... }: with lib;
let
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
  options.roos = {
    dotfilesPath = mkOption {
      type = with types; nullOr path;
      default = null;
      description = ''
        Path to external dotfiles repository. If defined, applications and
        services requiring files from such repository will be enabled.
      '';
    };

    user-profiles = mkOption {
      type = userProfileType;
      default = { reduced = []; simple = []; graphical = []; };
      description = "User profiles enabled in this system.";
    };

    rConfig = mkOption {
      type = options.home-manager.users.type.nestedTypes.elemType;
      default = {
        home.stateVersion = "18.09";
      };
      description = ''
        Home-manager configuration to be used in user-profiles with reduced
        configuration enabled.
      '';
    };

    rConfigFn = mkOption {
      default = _: {};
      description = ''
        Function returning a Home-manager configuration to be used in
        user-profiles with reduced configuration enabled.
        The function will be called with the user configuration as
        argument (i.e. `config.home-manager.users.$${user}`).
      '';
    };

    sConfig = mkOption {
      type = options.home-manager.users.type.nestedTypes.elemType;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with simple
        configuration enabled; in particular without a graphical session.
      '';
    };

    sConfigFn = mkOption {
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
      type = options.home-manager.users.type.nestedTypes.elemType;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with graphical
        configuration enabled. This will in all cases exclude the root user.
      '';
    };

    gConfigFn = mkOption {
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
      userXcfg = cartesianProduct
        { user = users; cfg = cfgFilter options.roos; };
    in mkMerge (map (x: {
      ${x.user} = mkAliasDefinitions x.cfg;
    }) userXcfg);
    mergeFunctorWithUser = user: x:  # x is a merge of functions to user configs
      mkMerge (map (f: f config.home-manager.users.${user}) x.contents);
    callUserCfgFns = users: cfgFilter: let
      userXcfgfn = cartesianProduct
        { user = users; cfgFn = cfgFilter options.roos; };
    in mkMerge (map (x: {
      ${x.user} = mkAliasAndWrapDefinitions
        (mergeFunctorWithUser x.user) x.cfgFn;
    }) userXcfgfn);
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
    usersWithProfiles =
      flatten (with config.roos.user-profiles; [ graphical reduced simple ]);
  in {
    home-manager.users = mkMerge (attrValues userCfgs);
    # See <https://github.com/rycee/home-manager/issues/1120>.
    # home-manager.useUserPackages = true;
    home-manager.verbose = true;

    assertions = [
      {
        assertion = let
          dotfiles = config.roos.dotfilesPath;
          try = builtins.tryEval (builtins.readDir (builtins.toPath dotfiles));
        in (dotfiles == null) || try.success;
        message = "The specified dotfilesPath is not a directory\
                   or is otherwise unaccesible";
      }
    ] ++ map (user: {
      assertion = builtins.hasAttr user config.users.users;
      message = "The main user ${user} has to exist";
    }) usersWithProfiles;
  };
}
