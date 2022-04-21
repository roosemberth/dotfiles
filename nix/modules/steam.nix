{ config, pkgs, lib, ... }: with lib;
{
  options.roos.steam.enable = mkEnableOption "Enable steam support";

  config = mkIf config.roos.steam.enable {
    roos.gConfig.home.packages = with pkgs; [steam steam.run];

    hardware.opengl.driSupport32Bit = true;
    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    hardware.pulseaudio.support32Bit = true;
    hardware.steam-hardware.enable = true;
  };
}
