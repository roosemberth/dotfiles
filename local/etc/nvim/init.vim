" (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/
" Based on my own previous nvim configuration, available on gitlab, under tag
" prereset-2020.

" -----------------------------------------------------------------------------
" Plugins {{{
if has('vim_starting')
  if !filereadable(stdpath('data').'/site/autoload/plug.vim')
    exe '!curl -fLo '.stdpath('data').'/site/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    let s:should_bootstrap_plug=1
  endif
endif

call plug#begin(stdpath('cache').'/vim-plug')

" Appearance
Plug 'morhetz/gruvbox'
Plug 'vim-airline/vim-airline'

" Integrations
Plug 'francoiscabrol/ranger.vim'
Plug 'mileszs/ack.vim'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-tbone'
Plug 'w0rp/ale'

" Behaviour
Plug 'JarrodCTaylor/vim-reflection'
Plug 'Lokaltog/vim-easymotion'
Plug 'Shougo/denite.nvim'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' } " FIXME: broken post-install?
Plug 'chrisbra/vim-diff-enhanced'
Plug 'junegunn/vim-easy-align'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-surround'
Plug 'vim-scripts/LargeFile'

" Filetypes
Plug 'IN3D/vim-raml'
Plug 'LnL7/vim-nix'
Plug 'Matt-Deacalion/vim-systemd-syntax'
Plug 'Shougo/vinarise.vim'
Plug 'ap/vim-css-color'
Plug 'ferrine/md-img-paste.vim'
Plug 'idris-hackers/idris-vim'
Plug 'lervag/vimtex'
Plug 'vim-scripts/AnsiEsc.vim'
Plug 'vim-scripts/Arduino-syntax-file'
Plug 'vim-scripts/deb.vim'

call plug#end()

if exists('s:should_bootstrap_plug')
  PlugInstall
  unlet s:should_bootstrap_plug
endif
" }}}

" -----------------------------------------------------------------------------
" General options {{{
set cmdwinheight=10  " Show 10 last commands in the window
set colorcolumn=81,121
set foldmethod=marker
set history=10000
set mouse=nvi  " enable mouse in all modes but command
set scrolloff=3  " Keep 3 lines 'padding' above/below the cursor
set showmatch  " Highlight matching open parentheses when closing
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

set wrap linebreak
au FileType html,java,scala setl nowrap

" https://github.com/torvalds/linux/pull/17#issuecomment-5661185
au FileType gitcommit setl textwidth=72
" }}}

colorscheme gruvbox
set background=dark

" -----------------------------------------------------------------------------
" Plugin configuration {{{
" Integrations plugins
if executable('ag') " Use ag instead of ack if possible
  let g:ackprg = 'ag --vimgrep'
endif

let b:ale_python_mypy_options="--ignore-missing-imports"
let b:ale_python_pylint_options="--disable=import-error"
let g:ale_echo_msg_format = '[%linter%] %s [%severity%:%code%]'
let g:ale_lint_on_insert_leave=1
let g:ale_lint_on_text_changed="normal"

" fix gruvbox's highlight for Ale
highlight ALEInfo ctermfg=109 cterm=italic
highlight ALEWarning ctermfg=214 cterm=italic
highlight ALEError ctermfg=167 cterm=italic

" Behaviour plugins
call deoplete#enable()

" Denite {{{
autocmd FileType denite call s:denite_my_settings()
function! s:denite_my_settings() abort
  nnoremap <silent><buffer><expr> <CR>    denite#do_map('do_action')
  nnoremap <silent><buffer><expr> s       denite#do_map('do_action', 'vsplit')
  nnoremap <silent><buffer><expr> S       denite#do_map('do_action', 'split')
  nnoremap <silent><buffer><expr> d       denite#do_map('do_action', 'delete')
  nnoremap <silent><buffer><expr> p       denite#do_map('do_action', 'preview')
  nnoremap <silent><buffer><expr> q       denite#do_map('quit')
  nnoremap <silent><buffer><expr> i       denite#do_map('open_filter_buffer')
  nnoremap <silent><buffer><expr> <Space> denite#do_map('toggle_select').'j'

  call denite#custom#var('grep', 'command', ['ag'])
  call denite#custom#var('grep', 'default_opts', ['-i', '--vimgrep'])
  call denite#custom#var('grep', 'recursive_opts', [])
  call denite#custom#var('grep', 'pattern_opt', [])
  call denite#custom#var('grep', 'separator', ['--'])
  call denite#custom#var('grep', 'final_opts', [])
endfunction

autocmd FileType denite-filter call s:denite_filter_my_settings()
function! s:denite_filter_my_settings() abort
  imap <silent><buffer> <C-o>     <Plug>(denite_filter_quit)
endfunction

" Have denite use scantree.py since it respects wildignore
call denite#custom#var('file/rec', 'command',
                       \ ['scantree.py', '--path', ':directory'])

" }}}
" }}}

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

" Exploring files
nnoremap <leader>g :e %:h:r<CR>
au BufEnter fugitive://* nnoremap <buffer> <leader>f :e %:h:r<CR>
nnoremap <leader>T :Denite tag<CR>
nnoremap <leader>F :Denite file/rec file/old<CR>
nnoremap <leader>B :Denite buffer<CR>
nnoremap <leader>J :Denite jump<CR>
nnoremap <leader><C-_> :Denite line<CR>
nnoremap <C-w>w :rightbelow wincmd f<CR>
nnoremap <C-w>e :rightbelow vertical wincmd f<CR>

" EasyAlign
vnoremap ga <Plug>(EasyAlign)
nnoremap ga <Plug>(EasyAlign)

" Fugitive
nnoremap <leader>s :Gstatus<CR>
nnoremap <leader>d :Gdiff<CR>
nnoremap <leader>w :Gwrite<CR>
nnoremap <leader>c :Gcommit -S -v -s 
nnoremap <leader><C-t> :vs term://%:h:r//tig<CR>i

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
nnoremap <leader><C-n> :set hlsearch!<CR>
nnoremap & :let @/=expand("<cword>")<CR>
nnoremap <leader>* :AckFromSearch<CR>

" Everything else...
cnoremap w!! w !sudo tee % >/dev/null<CR>
vnoremap <C-F2> d:execute 'normal i' . join(sort(split(getreg('"'))), ' ')<CR>
nnoremap <leader>t :TagbarOpenAutoClose<CR>
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

au FileType fugitive nnoremap <buffer> <leader>l :execute '
  \:! git log --oneline --graph --decorate=short FETCH_HEAD^..HEAD' <CR>

au FileType markdown nnoremap <silent> <leader>p :execute '
  \:call mdip#MarkdownClipboardImage()' <CR>  " Markdown img clipboard

au BufEnter * call OnBufEnter()

au BufEnter fugitive://* nmap Q :q:q
" }}}

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80
