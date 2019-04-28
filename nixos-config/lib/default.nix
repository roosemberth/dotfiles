{ pkgs, lib, ... }: with lib; {
  _module.args.mylib = {
    wireguard = import ./systech-wireguard.nix { inherit lib; };
  };
}
