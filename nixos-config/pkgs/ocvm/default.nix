{ stdenv, fetchFromGitHub, subversion, lua5_3, pkgconfig, cacert, wget, writeText }:

stdenv.mkDerivation {
  name = "ocvm";

  src = fetchFromGitHub {
    owner = "payonel";
    repo = "ocvm";
    rev = "e49e1c5a0ef47838c43fa3b94991c0dfa4ff29cc";
    sha256 = "0dx939w3cbdg735pa4r9drd7r9x0q2bzhks7v3l5dvxcp54z6xv3";
  };

  patches = [
    (writeText "fix-hardcoded-paths.patch" ''
      --- a/client.cfg
      +++ b/client.cfg
      @@ -22,7 +22,7 @@
               -- filesystem
               -- 1. source: uri for readonly loot, nil/false for hdd, and true for tmpfs
               -- 2. label
      -        {"filesystem", nil, "system/loot/openos", "OpenOS"},
      +        {"filesystem", nil, "../lib/system/loot/openos", "OpenOS"},
               {"filesystem", nil, true, "tmpfs"},
               {"filesystem"},

      --- a/main.cpp
      +++ b/main.cpp
      @@ -104,19 +104,19 @@ struct Args
           string bios_path() const
           {
               string value = get(keys[Args::BiosKey]);
      -        return value.empty() ? fs_utils::make_proc_path("system/bios.lua") : value;
      +        return value.empty() ? fs_utils::make_proc_path("../lib/system/bios.lua") : value;
           }

           string machine_path() const
           {
               string value = get(keys[Args::MachineKey]);
      -        return value.empty() ? fs_utils::make_proc_path("system/machine.lua") : value;
      +        return value.empty() ? fs_utils::make_proc_path("../lib/system/machine.lua") : value;
           }

           string fonts_path() const
           {
               string value = get(keys[Args::FontsKey]);
      -        return value.empty() ? fs_utils::make_proc_path("system/font.hex") : value;
      +        return value.empty() ? fs_utils::make_proc_path("../lib/system/font.hex") : value;
           }
       };

      --- a/model/config.cpp
      +++ b/model/config.cpp
      @@ -32,7 +32,7 @@ bool Config::load(const string& path, const string& name)
           // if save path has no client.cfg, copy it from proc_root
           if (!fs_utils::exists(savePath()))
           {
      -        if (!fs_utils::copy(fs_utils::make_proc_path("client.cfg"), savePath()))
      +        if (!fs_utils::copy(fs_utils::make_proc_path("../lib/client.cfg"), savePath()))
               {
                   *_pLout << "failed to copy new client.cfg\n";
                   return false;
    '')
  ];

  buildInputs = [ lua5_3 pkgconfig subversion cacert wget ];

  makeFlags = ["lua=5.3"];

  installPhase = ''
    mkdir -p $out/bin $out/lib
    cp ocvm $out/bin
    cp -r system client.cfg $out/lib
  '';
}
