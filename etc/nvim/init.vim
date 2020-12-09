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
Plug 'airblade/vim-gitgutter'
Plug 'francoiscabrol/ranger.vim'
Plug 'mileszs/ack.vim'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-tbone'
Plug 'w0rp/ale'
Plug 'vimwiki/vimwiki', { 'on': 'VimwikiIndex' }
try " Do not load taskwiki if tasklib module is not installed.
  py3 import tasklib
  Plug 'tools-life/taskwiki', { 'on': 'VimwikiIndex' }
catch
endtry
Plug 'direnv/direnv.vim'

" Behaviour
Plug 'JarrodCTaylor/vim-reflection'
Plug 'Lokaltog/vim-easymotion'
Plug 'chrisbra/vim-diff-enhanced'
Plug 'junegunn/vim-easy-align'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-surround'
Plug 'vim-scripts/LargeFile'
Plug 'vim-scripts/Mark'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'

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
Plug 'aklt/plantuml-syntax'

" Coc-stuff
if executable('node') && executable('yarn')
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  if executable('clangd')
    Plug 'clangd/coc-clangd', {'do': 'yarn install --frozen-lockfile'}
  endif
  if executable('java')
    Plug 'neoclide/coc-java', {'do': 'yarn install --frozen-lockfile'}
  endif
endif

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

let g:tex_flavor = 'latex'

let b:ale_python_mypy_options="--ignore-missing-imports"
let b:ale_python_pylint_options="--disable=import-error"
let g:ale_echo_msg_format = '[%linter%] %s [%severity%:%code%]'
let g:ale_lint_on_insert_leave=1
let g:ale_lint_on_text_changed="normal"
let g:ale_linters_ignore=
  \ { 'haskell': ['stack-build']
  \ }

" fix gruvbox's highlight for Ale
highlight ALEInfo ctermfg=109 cterm=italic
highlight ALEWarning ctermfg=214 cterm=italic
highlight ALEError ctermfg=167 cterm=italic

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

" Language server stuff
set updatetime=300
set shortmess+=c
set signcolumn=yes

call coc#config('languageserver',
  \{ "haskell": {
  \    "command": "haskell-language-server-wrapper",
  \    "args": ["--lsp"],
  \    "rootPatterns": [ "*.cabal", "package.yaml" ],
  \    "filetypes": [ "hs", "lhs", "haskell", "lhaskell" ],
  \  }
  \})

if executable('haskell-language-server-wrapper')
  let g:ale_linters_ignore=
    \ { 'haskell': ['stack-build', 'ghc', 'stack_ghc']
    \ }
endif

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <silent><expr> <TAB>
      \ pumvisible() ? "<Down>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
inoremap <silent><expr> <C-n> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current
" position. Coc only does snippet and additional edit on confirm.
if exists('*complete_info')
  inoremap <expr> <cr> complete_info()["selected"] != "-1"
    \? "\<C-y>" : "\<C-g>u\<CR>"
else
  imap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
endif

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

" Handy commands
command! -nargs=0 Format :call CocAction('format') |
  \:call CocAction('runCommand', 'editor.action.organizeImport')
command! -nargs=? Fold :call CocAction('fold', <f-args>)
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
au BufEnter fugitive://* nnoremap <buffer> <leader>f :e %:h:r<CR>
nnoremap <leader>T :Tags<CR>
nnoremap <leader>S :GFiles?<CR>
nnoremap <leader>F :Files<CR>
nnoremap <leader><C-f> :call <SID>fzf_dirmark()<CR>
nnoremap <leader>B :Buffers<CR>
nnoremap <leader><C-_> :Lines<CR>
nnoremap <C-w>w :rightbelow wincmd f<CR>
nnoremap <C-w>e :rightbelow vertical wincmd f<CR>
nnoremap <C-w>f :split +Ranger<CR>

" EasyAlign
vmap ga <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)

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
nnoremap & :let @/=expand("<cword>")<CR>
nnoremap <leader>* :AckFromSearch<CR>
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

" Language server
nmap <leader>rn <Plug>(coc-rename)
nmap <leader>ac <Plug>(coc-codeaction)
nmap <leader>qf <Plug>(coc-fix-current)

nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

nnoremap <silent> I          :call CocAction('doHover')<CR>
nnoremap <silent> <C-A>      :CocList actions<CR>

" Vimwiki
nnoremap <leader>ww :VimwikiIndex<CR>

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

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80:bufhidden=delete
