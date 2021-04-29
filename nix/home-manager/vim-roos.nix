{ pkgs, config, lib, ... }: with lib; {
  options.programs.vim-roos.enable = mkEnableOption "Roos' vim configuration";
  config = mkIf config.programs.vim-roos.enable {
    home.packages = [ pkgs.nvim-roos ];
  };
}
