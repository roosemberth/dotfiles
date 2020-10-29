{ config, pkgs, lib, secrets, ... }: with lib;
{
  options.roos.eivd.enable =
    mkEnableOption "Stuff required during my studies at HEIG-VD";

  config = mkIf config.roos.eivd.enable {
    roos.sConfig = {
      home.packages = with pkgs; [
        # POO1
        (maven.override { jdk = openjdk14; })
        openjdk14
      ];
    };
}
