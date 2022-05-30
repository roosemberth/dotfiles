{ config, pkgs, lib, ... }: with lib; let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.dev.enable = mkEnableOption "Install language development packages";

  config = mkIf config.roos.dev.enable {
    roos.sConfig = {
      services.lorri.enable = true;
      home.packages = with pkgs; [
        # Other
        httpie
        wdiff
        jq
        yq
        virt-viewer
        claws
        usbutils
        # lorri
        direnv
        # Nix
        manix
      ];

      xdg.configFile."stylish-haskell/config.yaml".source =
        util.fetchDotfile "etc/stylish-haskell.yaml";
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
    '';
  };
}
