" (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/

" Vim options that require no plugins but mere vanilla Neovim go here.

" -----------------------------------------------------------------------------
" General options {{{
set cmdwinheight=10       " Show 10 last commands in the window
set colorcolumn=81,121
set foldmethod=marker
set history=10000
set mouse=nvi             " enable mouse in all modes but command
set scrolloff=3           " Keep 3 lines 'padding' above/below the cursor
set showmatch             " Highlight matching open parentheses when closing
set title
set wildignore+=result,.* " Ignore nix-build result link and hidden files

set ignorecase smartcase  " Ignore case, except when query contains Uppercase
set list listchars=tab:→\ ,eol:\ ,trail:·
set number relativenumber numberwidth=5

if $TERM == 'linux'
  set fillchars=vert:.
else
  set fillchars=vert:│
endif
set fillchars+="fold: "

set undofile
au BufWritePre /tmp/*,/dev/shm/*,/run/shm/* setl noundofile

filetype plugin indent on
set autoindent copyindent

set expandtab tabstop=2 shiftwidth=2
au FileType c setl tabstop=4 shiftwidth=4

set nowrap linebreak

" https://github.com/torvalds/linux/pull/17#issuecomment-5661185
au FileType gitcommit setl textwidth=72
" }}}

" -----------------------------------------------------------------------------
" Syntax {{{
syntax on

" Fix unrecognised file types:
au BufRead,BufNewFile *.md setl filetype=markdown
au BufRead,BufNewFile *.tex setl filetype=tex
au BufRead,BufNewFile *.frag,*.vert,*.geom,*.glsl setl filetype=glsl

" Assembly:
let asmsyntax='nasm'

" C:
let c_no_curly_error=1 " Allow {} inside [] and () (non-ANSI)
let c_space_errors=1   " Highlight trailing spaces and spaces before tabs
let c_syntax_for_h=1   " Treat .h as C header files (instead of C++)

" Shell:
let g:is_posix=1       " /bin/sh is POSIX shell, not deprecated Bourne shell
" }}}

" -----------------------------------------------------------------------------
" Language-specific functions {{{
function! s:GenTags(sources)
  let temp_tags_file=tempname()
  execute "!ctags -f " . temp_tags_file . " -R " . a:sources
  execute "set tags=" . temp_tags_file
  set notagrelative
endfunction

" -> C {{{
function! FT_c()
  function! s:SetSingletonMake()
    let &l:makeprg='gcc ' . expand('%') .' -o ' . expand('%:r') . ' -O0 -g
          \ -W -Wall -Wextra -pedantic -Wcast-align -Wcast-qual -Wconversion
          \ -Wwrite-strings -Wfloat-equal -Wpointer-arith -Wformat=2
          \ -Winit-self -Wuninitialized -Wshadow -Wstrict-prototypes
          \ -Wmissing-declarations -Wmissing-prototypes -Wno-unused-parameter
          \ -Wbad-function-cast -Wunreachable-code && ' . expand("%:p:r")
  endfunction
  command! SetSingletonMake call s:SetSingletonMake()
endfunction
" }}} <- C

" -> Haskell {{{
function! FT_haskell()
  " Use fast-tags to generate tags file
  function! s:GenTags(sources)
    let temp_tags_file=tempname()
    execute "!fast-tags -o " . temp_tags_file . " -R " . a:sources
    execute "set tags=" . temp_tags_file
    set notagrelative
  endfunction
  setlocal keywordprg=hoogle\ -q\ --color\ --info
endfunction
" }}} <- Haskell

function! s:_GenTags(...)
  if a:0 == 1
    call s:GenTags(a:1)
  else
    call s:GenTags(".")
  endif
endfunction

command! -nargs=? -complete=dir GenTags call s:_GenTags(<f-args>)

au FileType c call FT_c()
au FileType haskell call FT_haskell()

set updatetime=300
set shortmess+=c
set signcolumn=yes
" }}}

" -----------------------------------------------------------------------------
" Whitespace {{{
function! StripTrailingWhitespaces()
  let _s=@/
  let l=line('.')
  let c=col('.')
  %s/\s\+$//eg
  call cursor(l,c)
  let @/=_s
endfunction
command! W :call StripTrailingWhitespaces() | :write
" }}}

" -----------------------------------------------------------------------------
" Folding {{{
function! CFold()  " Fold C function implemenations:
  let prevline = getline(v:lnum-1)
  let nextline = getline(v:lnum+1)
  if match(nextline, '^{') >= 0
    return 1
  elseif match(prevline, '^}') >= 0
    return 0
  else
    return "="
  endif
endfunction
au FileType c setl foldmethod=expr foldexpr=CFold()
" }}}

" -----------------------------------------------------------------------------
" Key bindings {{{
let mapleader=' '

" Simple cursor moving on visual lines:
map k gk
map j gj

" Agile navigation between windows:
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" terminal buffers:
tnoremap <Esc> <C-\><C-n>
tnoremap <A-[> <Esc>
tnoremap <C-w>h <Cmd> wincmd h<CR>
tnoremap <C-w>j <Cmd> wincmd j<CR>
tnoremap <C-w>k <Cmd> wincmd k<CR>
tnoremap <C-w>l <Cmd> wincmd l<CR>
nnoremap <C-w>t :new \| call termopen([$SHELL], {'cwd': expand('#:p:h')}) \| startinsert<CR>
au BufEnter term://* startinsert

" Exploring files
nnoremap <leader>u :e %:h:r<CR>
nnoremap <C-w>w :rightbelow wincmd f<CR>
nnoremap <C-w>e :rightbelow vertical wincmd f<CR>

" Quickfix
nnoremap <leader>L :cclose<CR>
nnoremap <leader>l :copen<CR>
nnoremap <leader>k :cprevious<CR>
nnoremap <leader>j :cnext<CR>

" Emacs-like navigation in command-line mode
inoremap <C-f> <Right>
noremap! <C-a> <Home>
noremap! <C-b> <Left>
noremap! <C-e> <End>
noremap! <M-b> <S-Left>
noremap! <M-f> <S-Right>

" Search
nnoremap & :let @/=expand("<cword>")<CR>
nnoremap <silent> <Return> :set nohlsearch<CR><CR>
nnoremap <silent> N :set hlsearch<CR>N
nnoremap <silent> n :set hlsearch<CR>n

" Splits and forking
nnoremap <C-w><C-w> :split<CR>
nnoremap <C-w><C-e> :vsplit<CR>
nnoremap <C-w><C-t> :execute 'tabnew '.expand('%')<CR>
nnoremap <C-w>w :execute 'split '.expand('<cfile>')<CR>
nnoremap <C-w>e :execute 'vsplit '.expand('<cfile>')<CR>
nnoremap <C-w>t :execute 'tabnew '.expand('<cfile>')<CR>

" Misc
cnoremap w!! w !sudo tee % >/dev/null<CR>
vnoremap <C-F2> d:execute 'normal i' . join(sort(split(getreg('"'))), ' ')<CR>
nnoremap <leader>D :diffthis<CR>
vnoremap ! :!sh<CR>

function! OnBufEnter()
  if &buftype=="help"
    nmap <buffer> q :q<CR>
  endif
  if &previewwindow
    nmap <buffer> q :q<CR>
  endif
endfunction

au BufEnter * call OnBufEnter()

" }}}

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80:bufhidden=delete
