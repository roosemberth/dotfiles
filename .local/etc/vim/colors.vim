" Vim color scheme file.
"
"     2010-2017 - «ayekat»
" (C) 2016-2017 - Roosembert Palacios <roosembert.palacios@epfl.ch>
" Released under CC BY-NC-SA License: https://creativecommons.org/licenses/
" ------------------------------------------------------------------------------
" COLOUR SCHEME {{{

" Prevent vim default colour scheme from overriding this (since 7.4.764):
color default

" Make visual less penetrant:
hi Visual cterm=inverse ctermbg=0

" Non-printable characters (tabs, spaces, special keys):
hi SpecialKey cterm=bold ctermfg=238

" Matching parentheses:
hi MatchParen cterm=bold ctermfg=4 ctermbg=none

if $TERM != "linux"
	" Custom colour scheme for X vim {{{
	" Dropdown menu:
	hi Pmenu      ctermfg=244 ctermbg=234
	hi PmenuSel   ctermfg=45  ctermbg=23
	hi PmenuSbar              ctermbg=234
	hi PmenuThumb             ctermbg=31

	" Folding:
	hi Folded     ctermfg=248 ctermbg=236 cterm=none

	" Separate normal text from non-file-text:
	"hi NonText    ctermfg=0   ctermbg=232 cterm=bold

	" Window separator (XXX inverted for some reason):
	hi VertSplit  ctermfg=232 ctermbg=236

	" Line numbers and syntastic column:
	hi SignColumn             ctermbg=none
	hi LineNr                 ctermbg=0

	" 80 columns indicator:
	hi ColorColumn ctermbg=235

	" Search:
	hi Search             ctermfg=0  ctermbg=26

	" Diffs:
	hi DiffAdd            ctermfg=118 ctermbg=22
	hi DiffChange                     ctermbg=237
	hi DiffDelete         ctermfg=52  ctermbg=none
	hi DiffText           ctermfg=123 ctermbg=24   cterm=none

	" Gitdiffs:
	hi diffAdded          ctermfg=2
	hi diffRemoved        ctermfg=1

	" Syntax:
	hi Comment            ctermfg=243
	au FileType mail hi Comment ctermfg=34
	hi Constant           ctermfg=34
		" any constant | string | 'c' '\n' | 234 0xff | TRUE false | 2.3e10
		"hi String         ctermfg=
		"hi Character      ctermfg=
		"hi Number         ctermfg=
		"hi Boolean        ctermfg=
		"hi Float          ctermfg=

	hi Identifier         ctermfg=169
		" any variable name | function name (also: methods for classes)
		"hi Function       ctermfg=

	hi Statement          ctermfg=172
		" any statement | if then else endif switch | for do while |
		" case default | sizeof + * | any other keyword | exception
		"hi Conditional    ctermfg=
		"hi Repeat         ctermfg=
		"hi Label          ctermfg=
		"hi Operator       ctermfg=
		"hi Keyword        ctermfg=
		"hi Exception      ctermfg=

	hi PreProc            ctermfg=169
		" any preprocessor | #include | #define | macro | #if #else #endif
		"hi Include        ctermfg=
		"hi Define         ctermfg=
		"hi Macro          ctermfg=
		"hi PreCondit      ctermfg=
	au FileType sh hi PreProc ctermfg=38

	hi Type               ctermfg=38
		" int long char | static register volatile | struct union enum | typedef
		"hi StorageClass   ctermfg=
		"hi Structure      ctermfg=
		"hi Typedef        ctermfg=

	hi Special            ctermfg=136
		"hi SpecialChar    ctermfg=
		"hi Tag            ctermfg=
		"hi Delimiter      ctermfg=
		"hi SpecialComment ctermfg=
		"hi Debug          ctermfg=

	hi Todo               ctermfg=148 ctermbg=22
	hi Error              ctermfg=88  ctermbg=9  cterm=bold
		"hi SyntasticErrorSign
	" }}}
else
	" Custom colour scheme for TTY vim {{{
	set background=light

	" Window separator:
	hi VertSplit ctermfg=4 ctermbg=4 cterm=none

	" Folding:
	hi Folded ctermfg=3 ctermbg=8 cterm=none

	" Line numbers:
	hi LineNr ctermfg=3 ctermbg=0

	" Search:
	hi Search             ctermfg=0  ctermbg=3

	" Syntax:
	hi Statement ctermfg=3
	hi Todo ctermbg=3
	" }}}
endif

" }}}
" ------------------------------------------------------------------------------
