# Inspired from Infinisil's configuration repository @df9232c4

{ config, pkgs, lib, options, ... }: let
  home-manager-19_03 = builtins.fetchGit {
    url = "https://github.com/rycee/home-manager.git";
    rev = "ba0375bf06e0e0c3b2377edf913b7fddfd5a0b40"; # CHANGEME
    ref = "release-19.03";
  };
  home-manager =
    let try = builtins.tryEval <home-manager>;
    in if try.success then try.value
       else builtins.trace "Using pinned version for home manager" home-manager-19_03;
in with lib; {
  imports = [ (home-manager + "/nixos") ];

  options.roos = {
    mainUsers = mkOption {
      type = types.listOf types.str;
      example = [ "paul" "john" ];
      default = [];
      description = "Main users for this system";
    };

    xUserConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = "Home-manager configuration to be used for all main X users, this will in all cases exclude the root user";
    };

    userConfig = mkOption {
      type = options.home-manager.users.type.functor.wrapped;
      default = {};
      description = "Home-manager configuration to be used for all main users";
    };
  };

  config = {
    home-manager.users = mkMerge (flip map config.roos.mainUsers (user: {
      ${user} = mkMerge [
        (mkAliasDefinitions options.roos.userConfig)
        (mkIf (config.services.xserver.enable && user != "root")
          (mkAliasDefinitions options.roos.xUserConfig))
      ];
    }));
    home-manager.useUserPackages = true;

    assertions = map (user: {
      assertion = builtins.hasAttr user config.users.users;
      message = "The main user ${user} has to exist";
    }) config.roos.mainUsers;
  };
}
