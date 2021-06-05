{ neovim
, fetchFromGitHub
, lib
, vimPlugins
, vimUtils
, nix
, nixUnstable
, ...
}: let
  Mark = vimUtils.buildVimPluginFrom2Nix {
    pname = "Mark";
    version = "1.1.8-g";
    src = fetchFromGitHub {
      owner = "vim-scripts";
      repo = "Mark";
      rev = "62aa8276d8f3dac379b70c673baead4e11dbc1ec";
      hash = "sha256-+/VLiIqNU9H3CGjsAZqPZ2r035pKO38JjJ5rvJtFI94=";
    };
    meta.homepage = "https://github.com/vim-scripts/Mark/";
  };
  md-img-paste-vim = vimUtils.buildVimPluginFrom2Nix {
    pname = "md-img-paste.vim";
    version = "2020-10-11";
    src = fetchFromGitHub {
      owner = "ferrine";
      repo = "md-img-paste.vim";
      rev = "0a15d1ff890137657494bd8ae22aa81aa1354fdb";
      hash = "sha256-6cOSF04+yWw0dTN9ybeRXl7KEc+Gx57IcG045dRXKLI=";
    };
    meta.homepage = "https://github.com/ferrine/md-img-paste.vim";
  };
  deorise-nvim = vimUtils.buildVimPluginFrom2Nix {
    pname = "deorise.nvim";
    version = "2021-01-25";
    src = fetchFromGitHub {
      owner = "Shougo";
      repo = "deorise.nvim";
      rev = "0d2f2f42ed02acebb3cf88f22ea81ce05804517d";
      hash = "sha256-lbIkJqPd7go83JIcj7fR4WyPRlO86N/1mbFi2x+jdDI=";
    };
    meta.homepage = "https://github.com/Shougo/deorise.nvim";
  };
  arduino-syntax-file = vimUtils.buildVimPluginFrom2Nix {
    pname = "arduino-syntax-file";
    version = "2015-05-20";
    src = fetchFromGitHub {
      owner = "vim-scripts";
      repo = "Arduino-syntax-file";
      rev = "a09e9b49a8c1f1b619b69096cf43b575bb2d1173";
      hash = "sha256-zo5hOP+wN0zsDAndnbTiXbd+JggFHYYIYClVsLIZfGo=";
    };
    meta.homepage = "https://github.com/vim-scripts/Arduino-syntax-file/";
  };
  deb = vimUtils.buildVimPluginFrom2Nix {
    pname = "deb";
    version = "2010-10-18";
    src = fetchFromGitHub {
      owner = "vim-scripts";
      repo = "deb.vim";
      rev = "21b952e30ce261688efe1df324837a64ed28c68c";
      hash = "sha256-6cOSF04+yWw0dTN9ybeRXl7KEc+Gx57IcG045dRXKLI=";
    };
    meta.homepage = "https://github.com/vim-scripts/deb.vim/";
  };
  mynix-tools = let
    # Should stabilize once nix has been upgraded.
    nix' = assert !lib.versionAtLeast nix.version "2.4"; nixUnstable;
  in vimUtils.buildVimPluginFrom2Nix {
    pname = "nix-edit";
    version = "0.0";
    src = ./mynix-tools;
    propagatedBuildInputs = [ nix' ];
  };
in neovim.override {
  vimAlias = true;
  extraPython3Packages = p: with p; [ tasklib ];
  configure = {
    customRC = let
      entries = map builtins.readFile [
        ./core.vim
        ./essentials.vim
        ./languageSupport.vim
      ];
    in lib.concatStringsSep "\n" (lib.filter (x: x != "") entries) + ''
      " Manually configured entries to use Plug's lazy load feature
      source ${vimPlugins.vim-plug.rtp}/plug.vim
      call plug#begin(tempname())

      Plug '${vimPlugins.vimwiki.rtp}', { 'on': 'VimwikiIndex' }
      try " Do not load taskwiki if tasklib module is not installed.
        py3 import tasklib
        Plug '${vimPlugins.taskwiki.rtp}', { 'on': 'VimwikiIndex' }
      catch
      endtry

      call plug#end()
    '';
    packages.essentials = with vimPlugins; {
      start = [
        # Visuals
        Mark
        traces-vim
        vim-airline
        vim-css-color
        vim-gruvbox8
        vim-highlightedyank

        # Integrations
        ack-vim
        md-img-paste-vim
        ranger-vim
        vim-dispatch
        vim-fugitive
        vim-gitgutter
        vim-tbone

        # Behaviour
        fzf-vim
        nvim-autopairs
        quickfix-reflector-vim
        vim-easy-align
        vim-surround
      ];
    };
    packages.languageSupport = with vimPlugins; {
      start = [
        Improved-AnsiEsc
        ale
        arduino-syntax-file
        dart-vim-plugin
        deb
        deorise-nvim
        plantuml-syntax
        vim-clang-format
        vim-markdown
        vim-nix
        vimtex
        mynix-tools

      # Ideally, I would like to load coc & friends on-demand...
      #];
      #opt = [

        coc-clangd
        coc-clangd
        coc-java
        coc-json
        coc-markdownlint
        coc-nvim
        coc-pyright
        coc-spell-checker
        coc-tsserver
        coc-eslint
      ];
    };
  };
}
