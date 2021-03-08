{ pkgs, config, lib, ... }: with lib;
{
  options.programs.test-service.enable =
    mkEnableOption "Simple service logging to systemd it ran";
  config = mkIf config.programs.test-service.enable {
    systemd.user.services.test-service = {
      Service.ExecStart = builtins.toString
        (pkgs.writeShellScript "test-service"
          "echo 'User process ran' | ${pkgs.systemd}/bin/systemd-cat");
      Service.RemainAfterExit = true;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
