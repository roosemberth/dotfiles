" Vim color scheme file.
"
"     2010-2017 - «ayekat»
" (C) 2016-2017 - Roosembert Palacios <roosembert.palacios@epfl.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/
" ------------------------------------------------------------------------------
" STATUSLINE {{{
" Written by ayekat on a cold day in december 2012, updated in december 2013

" Always display the statusline:
set laststatus=2

" Don't display the mode in the ruler; we display it in the statusline:
set noshowmode

" Separators {{{
if $TERM == "linux"
	let gitsym=""
	let sep="|"
	let lnum="LN"
else
	let gitsym="⎇ "
	let sep="│"
	let lnum="␤"
endif " }}}

" Colours {{{
if $TERM == 'linux'
	hi StatusLine   ctermfg=0 ctermbg=7 cterm=none
	hi StatusLineNC ctermfg=7 ctermbg=4 cterm=none
else
	" normal statusline:
	hi N_mode           ctermfg=22  ctermbg=148
	hi N_git_branch     ctermfg=148 ctermbg=8
	hi N_git_sep        ctermfg=236 ctermbg=8
	hi N_file           ctermfg=247 ctermbg=8
	hi N_file_emphasise ctermfg=7   ctermbg=8
	hi N_file_modified  ctermfg=3   ctermbg=8
	hi N_middle         ctermfg=244 ctermbg=236
	hi N_middle_sep     ctermfg=8   ctermbg=236
	hi N_warning        ctermfg=1   ctermbg=236
	hi N_pos            ctermfg=11  ctermbg=8
	hi N_cursor         ctermfg=0   ctermbg=7
	hi N_cursor_line    ctermfg=236 ctermbg=7
	hi N_cursor_col     ctermfg=8   ctermbg=7

	hi V_mode           ctermfg=52  ctermbg=208

	hi I_mode           ctermfg=8   ctermbg=7
	hi I_git_branch     ctermfg=7   ctermbg=31
	hi I_git_sep        ctermfg=23  ctermbg=31
	hi I_file           ctermfg=249 ctermbg=31
	hi I_file_emphasise ctermfg=7   ctermbg=31
	hi I_file_modified  ctermfg=3   ctermbg=31
	hi I_middle         ctermfg=45  ctermbg=23
	hi I_middle_sep     ctermfg=31  ctermbg=23
	hi I_warning        ctermfg=1   ctermbg=23
	hi I_pos            ctermfg=11  ctermbg=31

	" command statusline:
	hi cmd_mode              ctermfg=15  ctermbg=64
	hi cmd_info              ctermfg=7   ctermbg=0

	" default statusline:
	hi StatusLine            ctermfg=0   ctermbg=236 cterm=none
	hi StatusLineNC          ctermfg=8   ctermbg=236 cterm=none
endif
" }}}

" Active Statusline {{{
function! StatuslineActive()
	let l:statusline = ''
	let l:mode = mode()
	let l:git_branch = fugitive#head()

	" Mode {{{
	if l:mode ==? 'v' || l:mode == ''
		let l:statusline .= '%#V_mode#'
		if l:mode ==# 'v'
			let l:statusline .= ' VISUAL '
		elseif l:mode ==# 'V'
			let l:statusline .= ' V·LINE '
		else
			let l:statusline .= ' V·BLOCK '
		endif
	elseif l:mode == 'i'
		let l:statusline .= '%#I_mode# INSERT '
	else
		let l:statusline .= '%#N_mode# NORMAL '
	endif
	" }}}

	" Git {{{
	if l:git_branch != ''
		if l:mode == 'i'
			let l:statusline .= '%#I_git_branch# %{gitsym}'
		else
			let l:statusline .= '%#N_git_branch# %{gitsym}'
		endif
		let l:statusline .= l:git_branch
		if l:mode == 'i'
			let l:statusline .= ' %#I_git_sep#%{sep}'
		else
			let l:statusline .= ' %#N_git_sep#%{sep}'
		endif
	endif " }}}

	" Filename {{{
	if l:mode == 'i'
		let l:statusline .= '%#I_file#'
	else
		let l:statusline .= '%#N_file#'
	endif
	let l:statusline.=' %<%{expand("%:p:h")}/'
	if l:mode == 'i'
		let l:statusline.='%#I_file_emphasise#'
	else
		let l:statusline.='%#N_file_emphasise#'
	endif
	let l:statusline.='%{expand("%:t")} '
	" }}}

	" Modified {{{
	if &modified
		if l:mode == 'i'
			let l:statusline .= '%#I_file_modified#'
		else
			let l:statusline .= '%#N_file_modified#'
		endif
		let l:statusline .= '* '
	endif
	" }}}

	if l:mode == 'i'
		let l:statusline .= '%#I_middle# '
	else
		let l:statusline .= '%#N_middle# '
	endif

	" Readonly {{{
	if &readonly
		if l:mode == 'i'
			let l:statusline .= '%#I_warning#X%#I_middle# '
		else
			let l:statusline .= '%#N_warning#X%#N_middle# '
		endif
	endif
	" }}}

	let l:statusline .= '%='

	" File format, encoding, type, line count {{{
	let l:ff = &fileformat
	let l:fe = &fileencoding
	let l:ft = &filetype
	if l:ff != 'unix' && l:ff != ''
		let l:statusline .= ' '.l:ff.' '
		if l:mode == 'i'
			let l:statusline .= '%#I_middle_sep#%{sep}%#I_middle#'
		else
			let l:statusline .= '%#N_middle_sep#%{sep}%#N_middle#'
		endif
	endif
	if l:fe != 'utf-8' && l:fe != 'ascii' && l:fe != ''
		let l:statusline .= ' '.l:fe.' '
		if l:mode == 'i'
			let l:statusline .= '%#I_middle_sep#%{sep}%#I_middle#'
		else
			let l:statusline .= '%#N_middle_sep#%{sep}%#N_middle#'
		endif
	endif
	if l:ft != ''
		let l:statusline .= ' '.l:ft.' '
		if l:mode == 'i'
			let l:statusline .= '%#I_middle_sep#%{sep}%#I_middle#'
		else
			let l:statusline .= '%#N_middle_sep#%{sep}%#N_middle#'
		endif
	endif
	let l:statusline .= ' %{lnum} %L '
	" }}}

	" Buffer position {{{
	if l:mode == 'i'
		let l:statusline .= '%#I_pos#'
	else
		let l:statusline .= '%#N_pos#'
	endif
	let l:statusline .= ' %P '
	" }}}

	" Cursor position {{{
	let l:statusline .= '%#N_cursor_line# %3l'
	let l:statusline .= '%#N_cursor_col#:%02c %#N_middle#'
	" }}}

	return l:statusline
endfunction
" }}}

" Inactive Statusline {{{
function! StatuslineInactive()
	let l:statusline = ''
	let l:branch = fugitive#head()

	" mode:
	let l:statusline .= '        %{sep}'

	" filename:
	let l:statusline.=' %<%t %{sep}'

	" change to the right side:
	let l:statusline.='%='

	" line count:
	let l:statusline .= ' %{lnum} %L '

	" buffer position:
	let l:statusline.='%{sep} %P '

	" cursor position:
	let l:statusline .= '%{sep} %3l:%02c '

	return l:statusline
endfunction " }}}

function! StatuslineCommand() " {{{
	return '%#cmd_mode# COMMAND %#cmd_mode_end#%{sep}'
endfunction " }}}

" define when which statusline is displayed:
au! BufEnter,WinEnter * setl statusline=%!StatuslineActive()
au! BufLeave,WinLeave * set  statusline=%!StatuslineInactive()
au! CmdwinEnter       * setl statusline=%!StatuslineCommand()

" }}}
" ------------------------------------------------------------------------------
