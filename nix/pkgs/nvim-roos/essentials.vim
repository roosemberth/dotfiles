" (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/

" Vim options that require plugins from the 'essentials' package go here.
colorscheme gruvbox
set background=dark

" -----------------------------------------------------------------------------
" Plugin configuration {{{
if executable('ag') " Use ag instead of ack if possible
  let g:ackprg = 'ag --vimgrep'
endif

let g:tex_flavor = 'latex'

let g:vimwiki_list = [{'path': '~/Documents/0-Runtime/wiki/'}]
let g:vimwiki_key_mappings = { 'all_maps': 0, 'html': 1, 'mouse': 1 }

let g:airline#extensions#tabline#enabled = 1

function! s:fzf_dirmark()
  call fzf#run(fzf#wrap(
    \ { 'source':'cat ~/.local/var/lib/vim-dirmarks.txt'
    \ , 'sink': "Files"
    \ }))
endfunction
" }}}

" -----------------------------------------------------------------------------
" Key bindings {{{

" Exploring files
au BufEnter fugitive://* nnoremap <buffer> <leader>f :e %:h:r<CR>
nnoremap <leader>T :Tags<CR>
nnoremap <leader>S :GFiles?<CR>
nnoremap <leader>F :Files<CR>
nnoremap <leader><C-f> :call <SID>fzf_dirmark()<CR>
nnoremap <leader>B :Buffers<CR>
nnoremap <leader><C-_> :Lines<CR>
nnoremap <C-w>f :split +RangerEdit<CR>

" Ranger
map <leader>rr :RangerEdit<cr>
map <leader>rv :RangerVSplit<cr>
map <leader>rs :RangerSplit<cr>
map <leader>rt :RangerTab<cr>
map <leader>ri :RangerInsert<cr>
map <leader>ra :RangerAppend<cr>
map <leader>rc :set operatorfunc=RangerChangeOperator<cr>g@
map <leader>rd :RangerCD<cr>
map <leader>rld :RangerLCD<cr>

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

" Search
nnoremap <leader>* :AckFromSearch<CR>

" Vimwiki
nnoremap <leader>ww :VimwikiIndex<CR>

" }}}

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80:bufhidden=delete
