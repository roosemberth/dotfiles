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
      (ghc.withHoogle (p: with p; [
        QuickCheck
        aeson
        generic-arbitrary
        optparse-applicative
        parsec
        protolude
        quickcheck-instances
        yaml
      ]))
      haskellPackages.fast-tags
      haskell-language-server
      stack
      # Node
      nodejs
      yarn
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
      # Remarkable RNDIS mode
      ACTION=="add",SUBSYSTEM=="net",SUBSYSTEM=="usb",ATTRS{idProduct}=="4010",ATTRS{idVendor}=="04b3",NAME="reMarkable"

      # Have usb tty devices accesible
      ACTION=="add",SUBSYSTEMS=="usb",SUBSYSTEM=="tty",MODE="0666"
      # ESP8266 D1-mini
      ACTION=="add",ATTRS{idProduct}=="1a86",ATTRS{idVendor}=="7523",MODE="0666"
    '';
  };
}
