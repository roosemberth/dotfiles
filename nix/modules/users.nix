# Inspired from Infinisil's configuration repository @df9232c4
{ config, pkgs, lib, options, ... }: with lib;
let
  home-manager-19_03 = builtins.fetchGit {
    url = "https://github.com/rycee/home-manager.git";
    rev = "0d1ca254d0f213a118459c5be8ae465018132f74";
    ref = "release-19.09";
  };
  home-manager =
    let try = builtins.tryEval <home-manager>;
    in if try.success then try.value
       else builtins.trace "Using pinned version for home manager" home-manager-19_03;
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

    sConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = ''
        Home-manager configuration to be used in user-profiles with simple
        configuration enabled; in particular without a graphical session.
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
  };

  config = let
    mkUserCfgs = users: cfgFilter: let
      cfgs = cfgFilter options.roos;
    in mkMerge (flip crossLists [users cfgs] (user: cfg: {
      ${user} = mkAliasDefinitions cfg;
    }));
    userCfgs = with config.roos.user-profiles; {
      reduced   = mkUserCfgs reduced (c: with c; [rConfig]);
      simple    = mkUserCfgs simple  (c: with c; [rConfig sConfig]);
      graphical = let
        users = (filter (u: u != "root") graphical);
      in mkUserCfgs users (c: with c; [rConfig sConfig gConfig]);
    };
  in {
    home-manager.users = mkMerge (with userCfgs; [reduced simple graphical]);
    # See <https://github.com/rycee/home-manager/issues/1120>.
    # home-manager.useUserPackages = true;
    home-manager.verbose = true;

    assertions = map (user: {
      assertion = builtins.hasAttr user config.users.users;
      message = "The main user ${user} has to exist";
    }) (flatten (attrValues config.roos.user-profiles));
  };
}
