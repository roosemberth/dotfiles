{ config, pkgs, lib, ... }: with lib;
{
  options.roos.dev.enable = mkEnableOption "Install language development packages";

  config = mkIf config.roos.dev.enable {
    roos.gConfig.home.packages = with pkgs; [
      # C/C++
      clang
      clang-tools
      cmake
      ctags
      gnumake
      # Haskell
      ghc
      haskellPackages.fast-tags
      stack
      # Node
      nodejs
      yarn
      # Java
      maven
      openjdk11
      # Python
      python3Packages.black
      # Embedded
      platformio
      # Other
      httpie
      wdiff
      jq
      yq
      virt-viewer
    ];
  };
}
