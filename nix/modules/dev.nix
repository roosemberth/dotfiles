{ config, pkgs, lib, secrets, ... }: with lib; let
  util = import ./util.nix { inherit config pkgs lib; };
in {
  options.roos.dev.enable = mkEnableOption "Install language development packages";

  config = mkIf config.roos.dev.enable {
    roos.sConfig = {
      home.packages = with pkgs; [
        # Other
        claws
        docker-credential-helpers
        httpie
        jq
        kubectl
        rakudo
        rlwrap
        usbutils
        virt-viewer
        wdiff
        yq
        zed-editor
        # Nix
        manix sops nix-output-monitor
      ] ++ [
        (python3.withPackages(p: with p;[
          beautifulsoup4
          flask
          ipython
          python-lsp-server
          pyyaml
          requests
        ]))
      ] ++ (with haskellPackages; [  # Haskell development
        (ghc.withPackages
          (p: with p;[QuickCheck aeson lens http-conduit optparse-applicative yaml]))
        haskell-language-server
        cabal2nix
        cabal-install
        fourmolu
        hpack
      ]);

      xdg.configFile."stylish-haskell/config.yaml".source =
        util.fetchDotfile "etc/stylish-haskell.yaml";
    };

    services.udev.extraRules = let
      extend = ext: r: lib.recursiveUpdate ext r;
      usbrules =
        (map (extend { match."ACTION" = "add"; add."TAG" = "uaccess"; }) [
          # Remarkable tablet upload mode (I.MX6)
          { match."ATTR{idVendor}" = "15a2"; match."ATTR{idProduct}" = "0063"; }
          # Librem5 & devkits
          { match."ATTR{idVendor}" = "1fc9"; match."ATTR{idProduct}" = "012b"; }
          { match."ATTR{idVendor}" = "0525"; match."ATTR{idProduct}" = "a4a5"; }
          { match."ATTR{idVendor}" = "0525"; match."ATTR{idProduct}" = "b4a4"; }
          { match."ATTR{idVendor}" = "316d"; match."ATTR{idProduct}" = "4c05"; }
          # ESP8266/ESP32
          { match."ATTR{idProduct}" = "7523"; match."ATTR{idVendor}" = "1a86"; }
        ]);

      toprules =
        (map (extend { match."ACTION" = "add"; }) [
          # Remarkable RNDIS mode
          { match."SUBSYSTEMS" = "usb"; match."SUBSYSTEM" = "net";
            match."ATTRS{idProduct}" = "4010"; match."ATTRS{idVendor}" = "04b3"; 
            make."NAME" = "reMarkable";
          }
          # Have usb tty devices accesible
          { match."SUBSYSTEMS" = "usb"; match."SUBSYSTEM" = "tty";
            make."MODE"="0666";
        }
        ]);
    in ''
      ${concatMapStringsSep "\n" config.lib.udev.renderRule toprules}

      SUBSYSTEM!="usb", GOTO="usb_rules_end"
      ${concatMapStringsSep "\n" config.lib.udev.renderRule usbrules}
      LABEL="usb_rules_end"
    '';
  };
}
