{ pkgs }: with pkgs;
{
  liblms7002m = callPackage ./liblms7002m.nix {};

  libxtrx = libsForQt5.callPackage ./libxtrx.nix {};

  libxtrxdsp = callPackage ./libxtrxdsp.nix {};

  libxtrxll = callPackage ./libxtrxll.nix {};
}
