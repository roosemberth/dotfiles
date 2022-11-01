" Random commands and tools to ease my life with nix

" Based on the same-named function of vim-nix, but compatible with nix 2.4
function! nix#edit(attr)
  let output = system("nix eval --raw " . a:attr . ".meta.position")
  if match(output, "^error:") == -1
    let position = split(split(output, '"')[0], ":")
    execute "edit " . position[0]
  endif
endfunction

command! -bang -nargs=* NixEdit call nix#edit(<q-args>)
