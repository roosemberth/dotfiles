{ fetchFromGitHub
, jdt-language-server
, lib
, manix
, neovim
, nix
, nixUnstable
, ripgrep
, vimPlugins
, vimUtils
, ...
}: let
  Mark = vimUtils.buildVimPlugin {
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
  md-img-paste-vim = vimUtils.buildVimPlugin {
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
  arduino-syntax-file = vimUtils.buildVimPlugin {
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
  mynix-tools = vimUtils.buildVimPlugin {
    pname = "nix-edit";
    version = "0.0";
    src = ./mynix-tools;
    propagatedBuildInputs = [ nix ];
  };
  vim-raku = vimUtils.buildVimPlugin {
    pname = "vim-raku";
    version = "2023-05-21";
    src = fetchFromGitHub {
      owner = "Raku";
      repo = "vim-raku";
      rev = "f9ed159f2a6e733d544c3f674f9d2a1ed1c89654";
      hash = "sha256-SHi32oJfyixfa2pfSi0Ue2lxUlI3F4yrs46v/B5724w=";
    };
  };

  essentialPlugins = with vimPlugins; {
    start = [
      # Visuals
      Mark
      gruvbox-nvim
      traces-vim
      vim-airline
      vim-css-color
      vim-highlightedyank
      # Integrations
      md-img-paste-vim
      ranger-vim
      vim-dispatch
      vim-fugitive
      vim-gitgutter
      vim-tbone
      # Behaviour
      nvim-autopairs
      plenary-nvim
      quickfix-reflector-vim
      telescope-fzf-native-nvim
      telescope-nvim
      vim-easy-align
      vim-surround
    ];
  };

  lspPlugins = with vimPlugins; {
    start = [
      Improved-AnsiEsc
      arduino-syntax-file
      fidget-nvim
      mynix-tools
      nvim-dap
      nvim-jdtls
      nvim-lspconfig
      nvim-metals
      pgsql-vim
      plantuml-syntax
      rust-tools-nvim
      telescope-manix
      vim-markdown  # Provides syntax highlighting inside code blocks :D
      vim-nix
      vim-raku
      vim-terraform
    ];
  };

  composeConfig = files: let
    entries = map builtins.readFile files;
  in lib.concatStringsSep "\n" (lib.filter (x: x != "") entries);

  mkPlugSection = contents: ''
    " Manually configured entries to use Plug's lazy load feature
    source ${vimPlugins.vim-plug.outPath}/plug.vim
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

  full = neovim.override {
    vimAlias = true;
    extraMakeWrapperArgs = let bins = [ manix ripgrep ]; in
      "--prefix PATH : '${lib.makeBinPath bins}'";
    extraPython3Packages = p: with p; [ tasklib packaging ];
    configure = {
      customRC = composeConfig [
        ./core.vim
        ./essentials.vim
      ] + ''
        let g:jdtls_path = '${jdt-language-server}/bin/jdtls'
        luafile ${./lspconfig.lua}
      ''+ mkPlugSection ''
        Plug '${vimPlugins.vimwiki.outPath}', { 'on': 'VimwikiIndex' }
        try " Do not load taskwiki if tasklib module is not installed.
        py3 import tasklib
        Plug '${vimPlugins.taskwiki.outPath}', { 'on': 'VimwikiIndex' }
        catch
        endtry
      '';
      packages.essentials = essentialPlugins;
      packages.languageSupport = lspPlugins;
    };
  };
}
