{ nixpkgs ? import <nixpkgs> {} }:
with nixpkgs; {
  mfgtools = callPackage ./mfgtools {};
}
