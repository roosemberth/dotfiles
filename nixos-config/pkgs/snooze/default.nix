{ stdenv
, fetchFromGitHub
}:
stdenv.mkDerivation {
  name = "snoze";

  src = fetchFromGitHub {
    owner = "leahneukirchen";
    repo = "snooze";
    rev = "c95b0c00842219d98d43a5f859ecbb995e4d438e";
    sha256 = "01wr0x4c8rbm1805nic3hqgnrs0hjh2rr5hvapj4rr8whg16m9fx";
  };

  makeFlags = [ "DESTDIR=$(out)" "PREFIX=" ];
}
