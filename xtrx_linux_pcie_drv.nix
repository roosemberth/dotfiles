{ fetchFromGitHub, kernel, stdenv }:

stdenv.mkDerivation {
  name = "xtrx_linux_pcie_drv";
  version = "0.0.1-2-git-2019083101";
  nativeBuildInputs = [ kernel.moduleBuildDependencies ];

  enableParallelBuilding = true;
  hardeningDisable = [ "pic" ];

  preConfigure = ''
    export "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  '';
  installPhase = ''
    install -D xtrx.ko $out/lib/modules/${kernel.modDirVersion}/extra/xtrx.ko
  '';

  src = fetchFromGitHub {
    owner = "xtrx-sdr";
    repo = "xtrx_linux_pcie_drv";
    rev = "ab29a2b4a319ae225fe38bffc185545c997b4e85";
    sha256 = "1ci16zgf0vbg1zv7mpxddszmi9gvy5qgrwha3nmhbh7r6rx6hqnl";
  };
}
