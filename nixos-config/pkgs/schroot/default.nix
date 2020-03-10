{ stdenv
, boost
, clang
, coreutils
, cmake
, doxygen
, fetchgit
, gettext
, glibc
, gnugrep
, gnused
, groff
, lib
, libuuid
, linux-pam
, makeWrapper
, perlPackages
, pkgconfig
, utillinux
, btrfs-progs ? null
, lvm2 ? null
, zfs ? null
}:
stdenv.mkDerivation {
  name = "schroot";
  src = fetchgit {
    url = "https://salsa.debian.org/debian/schroot.git";
    rev = "779a0285f6ce323064cdbe1c9844559c18ddd139";
    sha256 = "0wrsnfhjifqrfzqp6nc1ghgm07wa6blkb1ig8dsh7j7xcx42vihs";
  };

  nativeBuildInputs = [ cmake doxygen makeWrapper pkgconfig ];

  buildInputs = [
    boost
    gettext
    groff
    libuuid
    linux-pam
    perlPackages.Po4a
  ];

  patches = [
    # Debian patches
    ./Add-support-for-more-compression-formats.patch
    ./Add-SESSION_SOURCE-and-CHROOT_SESSION_SOURCE.patch
    ./10mount-Move-mount-directory-to-var-run.patch
    ./Support-union-mounts-with-overlay-as-in-Linux-4.0.patch
    ./GCC5-fixes-on-regexes.patch
    ./schroot-mount-make-bind-mounts-private.patch
    ./schroot-mount-resolve-mount-destinations-while-chrooted.patch
    ./fix-test-suite-with-usrmerge.patch
    ./Unmount-everything-that-we-can-instead-of-giving-up.patch
    ./fix-killprocs.patch
    ./fix-bash-completion.patch
    ./fix_typos_in_schroot_manpage.patch
    ./update_czech_schroot_translation.patch
    ./update_french_schroot_manpage_translation_2018.patch
    ./update_german_schroot_manpage_translation_2018.patch
    ./zfs-snapshot-support.patch
    ./cross.patch
    # NixOS-specific patches
    ./0001-Don-t-set-schroot-binary-permissions.patch
    ./0002-pam-Use-sysconfdir-instead-of-hardcoded-path.patch
    ./0003-Override-schroot.conf-and-conf-directory-using-envir.patch
    ./0004-Use-su-pam-service.patch
    ./0005-Create-session-directory-if-it-doesn-t-exist.patch
    ./0006-Don-t-execute-scripts-wrapped-using-nixpkgs-wrapProg.patch
    ./0007-Add-MOUNT_EXECUTABLE-macro-to-CMakeLists.patch
    ./0008-setup-scripts-Remove-full-paths-from-various-command.patch
    ./0009-nssdatabases-Remove-gshadow-and-networks-databases.patch
  ];

  preConfigure = ''
    export NIX_CFLAGS_COMPILE="$(echo ${clang.default_cxx_stdlib_compile}) $NIX_CFLAGS_COMPILE"
  '';

  postInstall =
    let
      closure = [ coreutils glibc gnugrep gnused utillinux ]
        ++ lib.optional (btrfs-progs != null) btrfs-progs
        ++ lib.optional (lvm2 != null) lvm2
        ++ lib.optional (zfs != null) zfs;
    in ''
      while read -d $'\0' script; do
       wrapProgram "$script" --prefix PATH : "${lib.makeBinPath closure}"
      done  < <(find "$out/etc/schroot/setup.d/" -type f -print0)
    '';

  cmakeFlags = [
    "-DBOOST_ROOT=${boost}"
    "-DMOUNT_EXECUTABLE=${utillinux}/bin/mount"
    "-DSCHROOT_MOUNT_DIR=/var/run/schroot/session"
    "-DSCHROOT_SESSION_DIR=/var/lib/schroot/session"
    "-DSCHROOT_LIBEXEC_DIR=/${placeholder "out"}/bin/"
  ] ++ (if (lvm2 == null) then [
      "-Dlvm-snapshot=OFF"
    ] else [
      "-Dlvm-snapshot=ON"
      "-DLVCREATE_EXECUTABLE=${lvm2}/bin/lvcreate"
      "-DLVREMOVE_EXECUTABLE=${lvm2}/bin/lvremove"
    ]
  ) ++ (if (btrfs-progs == null) then [
      "-Dbtrfs-snapshot=OFF"
    ] else [
      "-Dbtrfs-snapshot=ON"
      "-DBTRFS_EXECUTABLE=${btrfs-progs}/bin/btrfs"
    ]
  ) ++ (if (zfs == null) then [
      "-Dzfs-snapshot=OFF"
    ] else [
      "-Dzfs-snapshot=ON"
      "-DZFS_EXECUTABLE=${zfs}/bin/zfs"
    ]
  );
}
