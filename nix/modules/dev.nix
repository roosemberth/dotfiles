{ config, pkgs, lib, ... }: with lib;
{
  options.roos.dev.enable = mkEnableOption "Install language development packages";

  config = mkIf config.roos.dev.enable {
    roos.sConfig.services.lorri.enable = true;
    roos.sConfig.home.packages = with pkgs; [
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
      openjdk14
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
      # lorri
      direnv
    ];

    services.udev.extraRules = ''
      # Remarkable tablet upload mode (I.MX6)
      ACTION=="add",ATTRS{idProduct}=="0063",ATTRS{idVendor}=="15a2",MODE="0666"
      # Have usb tty devices accesible
      ACTION=="add",SUBSYSTEMS=="usb",SUBSYSTEM=="tty",MODE="0666"
    '';
  };
}
