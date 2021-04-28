" (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/

" Vim options that require plugins from the 'languageSupport' package go here.

" Plugin configuration {{{

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

autocmd User CocNvimInit call coc#config('languageserver',
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
" Key bindings {{{

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

" Markdown clipboard image
au FileType markdown nnoremap <silent> <leader>p :execute '
  \:call mdip#MarkdownClipboardImage()' <CR>  " Markdown img clipboard

" }}}

" vim:expandtab:shiftwidth=2:tabstop=2:colorcolumn=80:bufhidden=delete
