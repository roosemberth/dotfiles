{ config, lib, pkgs, ... }:
with pkgs;
let
  xmonad = xmonad-with-packages.override {
    #ghcWithPackages = (haskellPackages.override {
    #  overrides = self: super: {
    #    xmonad = super.xmonad.override {
    #      X11 = super.X11.override {
    #        libX11 = enableDebugging xorg.libX11;
    #      };
    #    };
    #  };
    #}).ghcWithPackages;
    packages = self: [ self.xmonad-contrib self.xmonad-extras ];
  };
in {
  services.xserver.windowManager = {
    session = [{
      name = "xmonad";
      start = ''
        ulimit -c unlimited
        LD_LIBRARY_PATH=${pkgs.enableDebugging pkgs.xorg.libX11}/lib ${xmonad}/bin/xmonad &
        waitPID=$!
      '';
    }];
  };
  systemd.coredump = { enable = true; };
  environment.systemPackages = [ xmonad ];
}
