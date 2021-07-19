{ config, pkgs, lib, ... }: with lib;
let
  steam' = (pkgs.steam.override {
    extraPkgs = p: with p; [];
  }).overrideAttrs (o: {
    postFixup = o.postFixup or "" + ''
      for f in $(find $out/bin/ $out/libexec/ -type f -executable); do
        wrapProgram "$f" --set SDL_VIDEODRIVER x11
      done
    '';
  });
in
{
  options.roos.steam.enable = mkEnableOption "Enable steam support";

  config = mkIf config.roos.steam.enable {
    roos.gConfig.home.packages = [steam' steam'.run];

    hardware.opengl.driSupport32Bit = true;
    hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    hardware.pulseaudio.support32Bit = true;
    hardware.steam-hardware.enable = true;
  };
}
