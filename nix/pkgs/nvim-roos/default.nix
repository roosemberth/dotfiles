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
  mynix-tools = vimUtils.buildVimPluginFrom2Nix {
    pname = "nix-edit";
    version = "0.0";
    src = ./mynix-tools;
    propagatedBuildInputs = [ nix ];
  };

  essentialPlugins = with vimPlugins; {
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

  languageSupportPlugins = with vimPlugins; {
    start = [
      Improved-AnsiEsc
      ale
      arduino-syntax-file
      dart-vim-plugin
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

  nativeLspLanguageSupportPlugins = with vimPlugins; {
    start = [
      Improved-AnsiEsc
      arduino-syntax-file
      plantuml-syntax
      mynix-tools
      nvim-lspconfig
    ];
  };

  composeConfig = files: let
    entries = map builtins.readFile files;
  in lib.concatStringsSep "\n" (lib.filter (x: x != "") entries);

  mkPlugSection = contents: ''
    " Manually configured entries to use Plug's lazy load feature
    source ${vimPlugins.vim-plug.rtp}/plug.vim
    call plug#begin(tempname())

    ${contents}

    call plug#end()
  '';

in {
  core = neovim.override {
    vimAlias = true;
    configure.customRC = composeConfig [./core.vim] + mkPlugSection "";
  };

  essential = neovim.override {
    vimAlias = true;
    configure = {
      customRC = composeConfig [
        ./core.vim
        ./essentials.vim
      ] + mkPlugSection "";
      packages.essentials = essentialPlugins;
    };
  };

  full-coc-lsp = neovim.override {
    vimAlias = true;
    extraPython3Packages = p: with p; [ tasklib ];
    configure = {
      customRC = composeConfig [
        ./core.vim
        ./essentials.vim
        ./languageSupport.vim
      ] + mkPlugSection ''
        Plug '${vimPlugins.vimwiki.rtp}', { 'on': 'VimwikiIndex' }
        try " Do not load taskwiki if tasklib module is not installed.
        py3 import tasklib
        Plug '${vimPlugins.taskwiki.rtp}', { 'on': 'VimwikiIndex' }
        catch
        endtry
      '';
      packages.essentials = essentialPlugins;
      packages.languageSupport = languageSupportPlugins;
    };
  };

  full-native-lsp = neovim.override {
    vimAlias = true;
    extraPython3Packages = p: with p; [ tasklib ];
    configure = {
      customRC = composeConfig [
        ./core.vim
        ./essentials.vim
      ] + ''
        luafile ${./lspconfig.lua}
      ''+ mkPlugSection ''
        Plug '${vimPlugins.vimwiki.rtp}', { 'on': 'VimwikiIndex' }
        try " Do not load taskwiki if tasklib module is not installed.
        py3 import tasklib
        Plug '${vimPlugins.taskwiki.rtp}', { 'on': 'VimwikiIndex' }
        catch
        endtry
      '';
      packages.essentials = essentialPlugins;
      packages.languageSupport = nativeLspLanguageSupportPlugins;
    };
  };
}
