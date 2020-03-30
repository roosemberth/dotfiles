{ config, pkgs, lib, ... }: with lib;
let
  steam' = (pkgs.steam.override {
    nativeOnly = true;
  }).overrideAttrs(old: {
    meta.broken = false;
  });
in
{
  options.roos.steam.enable = mkEnableOption "Enable steam support";

  config = mkIf config.roos.steam.enable {
    nixpkgs.config.allowUnfreePredicate = pkg: getName pkg == "steam-original";

    roos.gConfig.home.packages = [steam' steam'.run];

    hardware.opengl.driSupport32Bit = true;
    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    hardware.pulseaudio.support32Bit = true;
    hardware.steam-hardware.enable = true;
  };
}
