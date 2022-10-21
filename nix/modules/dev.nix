{ config, pkgs, lib, secrets, ... }: with lib; let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.dev.enable = mkEnableOption "Install language development packages";

  config = mkIf config.roos.dev.enable {
    roos.sConfig = {
      home.packages = with pkgs; [
        awscli2
        # Other
        httpie
        wdiff
        jq
        yq
        virt-viewer
        claws
        usbutils
        # Nix
        manix sops
      ] ++ (with haskellPackages; [  # Haskell development
        (ghc.withPackages
          (p: with p;[QuickCheck aeson lens http-conduit optparse-applicative yaml]))
        haskell-language-server
        cabal2nix
        cabal-install
        brittany
        hpack
      ]);

      xdg.configFile."stylish-haskell/config.yaml".source =
        util.fetchDotfile "etc/stylish-haskell.yaml";

        home.file.".aws/credentials".text = let
          awsSecret = s: secrets.users.roosemberth.volatile."aws/mimir/${s}";
        in generators.toINI {} {
          default.aws_access_key_id = awsSecret "access_key_id";
          default.aws_secret_access_key = awsSecret "secret_access_key";
        };
        home.file.".aws/config".text = generators.toINI {} {
          default.region = "eu-west-3";
        };
    };

    services.udev.extraRules = ''
      # Remarkable tablet upload mode (I.MX6)
      ACTION=="add",ATTRS{idProduct}=="0063",ATTRS{idVendor}=="15a2",MODE="0666"
      # Remarkable RNDIS mode
      ACTION=="add",SUBSYSTEM=="net",SUBSYSTEM=="usb",ATTRS{idProduct}=="4010",ATTRS{idVendor}=="04b3",NAME="reMarkable"

      # Have usb tty devices accesible
      ACTION=="add",SUBSYSTEMS=="usb",SUBSYSTEM=="tty",MODE="0666"
      # ESP8266/ESP32
      ACTION=="add",SUBSYSTEM=="usb",ATTR{idProduct}=="7523",ATTR{idVendor}=="1a86",MODE="0666"

      # Librem5
      SUBSYSTEM!="usb", GOTO="librem5_devkit_rules_end"
      ATTR{idVendor}=="1fc9", ATTR{idProduct}=="012b", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="0525", ATTR{idProduct}=="a4a5", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="0525", ATTR{idProduct}=="b4a4", GROUP+="plugdev", TAG+="uaccess"
      ATTR{idVendor}=="316d", ATTR{idProduct}=="4c05", GROUP+="plugdev", TAG+="uaccess"
      LABEL="librem5_devkit_rules_end"
    '';
  };
}
