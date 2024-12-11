" (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/

" Vim options that require plugins from the 'essentials' package go here.
colorscheme gruvbox
set background=dark

" -----------------------------------------------------------------------------
" Plugin configuration {{{
let g:tex_flavor = 'latex'

let g:vimwiki_list = [{'path': '~/Documents/0-Runtime/wiki/'}]
let g:vimwiki_key_mappings = { 'all_maps': 0, 'html': 1, 'mouse': 1 }

let g:airline#extensions#tabline#enabled = 1
" }}}

" -----------------------------------------------------------------------------
" Key bindings {{{

" Exploring files
au BufEnter fugitive://* nnoremap <buffer> <leader>f :e %:h:r<CR>
nnoremap <leader>T :Telescope<CR>
nnoremap <leader>S :Telescope git_status<CR>
nnoremap <leader>F :Telescope find_files<CR>
nnoremap <leader>B :Telescope buffers<CR>
nnoremap <leader>_ :Telescope live_grep<CR>

" Ranger
nnoremap <C-w>f :split +RangerEdit<CR>
map <leader>rr :RangerEdit<cr>

" EasyAlign
vmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

" Fugitive
nnoremap <leader>s :Git<CR>
nnoremap <leader>d :Gdiff<CR>
nnoremap <leader>W :Gwrite<CR>
nnoremap <leader>c :Git commit -v -s -S<Space>
nnoremap <leader><C-t> :vs term://%:h:r//tig<CR>i
au FileType fugitive nnoremap <buffer> <leader>l :execute '
  \:! git log --oneline --graph --decorate=short FETCH_HEAD^..HEAD' <CR>

" Vimwiki
nnoremap <leader>ww :VimwikiIndex<CR>

" }}}

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80:bufhidden=delete
