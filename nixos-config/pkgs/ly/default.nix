{ stdenv
, fetchFromGitHub
, linux-pam
, xlibs
, lib
}:
stdenv.mkDerivation rec {
  pname = "ly";
  version = "0.4.0-git";

  # This does not work, .gitmodules is not in the correct location, see
  # https://github.com/cylgom/ly/blob/master/makefile#L110
  #src = fetchFromGitHub {
  #  owner = "cylgom";
  #  repo = "ly";
  #  fetchSubmodules = true;
  #  rev = "aaa34e09da646ed241cae649adecd05ff879bbe7";
  #  sha256 = lib.fakeSha256;
  #};

  # Impure build, because I don't have the time to manually package the submodules.
  src = assert (lib.assertMsg (lib.pathIsDirectory /tmp/ly)
                "Impure source of ly not found. Please clone ly and its submodules\"
                \"as specified in the project readme under /tmp/ly."
                ); /tmp/ly;

  patches = [
    ./0001-login.c-fix-minor-out-of-bound-strncpy.patch
    ./0002-login.c-Move-XDG-initialization-before-opening-the-p.patch
    ./0003-login.c-fix-several-Werror-format-truncation.patch
    ./0004-login.c-remove-useless-indentation-on-empty-lines.patch
    ./0005-login.c-Initialize-the-environment-before-setting-XD.patch
    ./0006-login.c-Do-not-clear-the-environment-upon-init.patch
    ./0007-termbox-add-missing-assert-statements.patch
  ];
  #src = ../tmp/ly;

  makeFlags = [ "DESTDIR=$(out)" "DATADIR=$(out)/lib/ly" ];

  postInstall = ''
    mv $out/usr/bin $out/bin
  '';

  buildInputs = [ linux-pam xlibs.libxcb ];
  postPatch = ''
    substituteInPlace sub/configator/src/configator.h --replace \
    "#define CONFIGATOR_MAX_LINE 80" \
    "#define CONFIGATOR_MAX_LINE 500"
  '';
}
