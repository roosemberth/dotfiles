{ config, lib, ... }: with lib; {
  _module.args.secrets =
    if (builtins.getEnv("NIX_NO_SECRETS") != "") then
      builtins.trace "Building without secrets" { secretsAvailable = false; }
    else
      let
        secrets = import ../secrets.nix {
          inherit lib;
          _called_by_injector = true;
        };
      in
        assert secrets.secretsAvailable; secrets;
}
