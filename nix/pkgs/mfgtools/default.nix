{ stdenv
, bzip2
, cmake
, fetchFromGitHub
, libusb1
, libzip
, openssl
, pkgconfig
, substituteAll
}:

stdenv.mkDerivation rec {
  name = "mfgtools";
  version = "1.3.191";
  nativeBuildInputs = [ cmake libusb1 libzip openssl pkgconfig bzip2 ];

  patches = [
    (substituteAll {
      inherit version;
      src = ./0001-libuuu-gen_ver-Remove-version-discovery.patch;
    })
  ];

  src = fetchFromGitHub {
    owner = "NXPmicro";
    repo = "mfgtools";
    rev = "uuu_${version}";
    sha256 = "sha256-CeOoUUT+dTsbCNRTtNSBZgvdpt1ZCK92VbM4e1qly6Q=";
  };
}
