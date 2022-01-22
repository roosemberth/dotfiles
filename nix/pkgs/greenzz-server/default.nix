{ stdenv
, fetchurl
, fetchFromGitLab
, lib
, buildMaven
, maven
, makeWrapper
, jre
}:
let
  project = fetchFromGitLab {
    owner = "roosemberth";
    repo = "greenzz";
    rev = "1c87f3e932490fbcc58324344df2157429bd248e";
    hash = "sha256-/FXH1pyDQYWGB6p5WAB4hOOJJ2qBeKCisqzyNm8LlCg=";
  };

  repository = stdenv.mkDerivation {
    name = "maven-repository";
    buildInputs = [ maven ];
    src = "${project}/src/server";
    patches = ./0001-Upgrade-log4j-version-due-to-CVE-2021-44228-CVE-2021.patch;
    buildPhase = ''
      mvn package -Dmaven.repo.local=$out -Dmaven.test.skip=true
    '';
    # Remove ephemeral files
    installPhase = ''
      find $out -type f \
        -name \*.lastUpdated -or \
        -name resolver-status.properties -or \
        -name _remote.repositories \
        -delete
    '';
    dontFixup = true;  # don't do any fixup
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-FX0YRZwT4okmVperUCObGGGhxV2DiUe6b+SojBryzqs=";
  };
in stdenv.mkDerivation rec {
  version = "210608.02";
  upstreamVersion = "0.0-SNAPSHOT";  # TODO: Merge with upstream when released
  pname = "greenzz-server";

  src = "${project}/src/server";
  patches = ./0001-Upgrade-log4j-version-due-to-CVE-2021-44228-CVE-2021.patch;

  buildInputs = [ maven makeWrapper ];

  buildPhase = ''
    echo "Using repository ${repository}"
    mvn --offline -Dmaven.repo.local=${repository} -Dmaven.test.skip=true \
      package
  '';

  installPhase = ''
    mkdir -p $out/bin
    classpath=$(find ${repository} -name "*.jar" -printf ':%h/%f');
    ARTIFACT="$out/share/java/${pname}-${version}.jar"
    install -Dm644 target/server-${upstreamVersion}.jar $ARTIFACT
    makeWrapper ${jre}/bin/java $out/bin/${pname} \
      --add-flags "-classpath $ARTIFACT:''${classpath#:}" \
      --add-flags "-jar $ARTIFACT"
  '';
}
