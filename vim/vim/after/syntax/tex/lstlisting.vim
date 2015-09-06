" lstlisting.vim: support for the lstlisting package
"   Author : Charles E. Campbell
"   Date   : Nov 25, 2013
"   Version: 1b	ASTRO-ONLY
" NOTE: Place this file in your $HOME/.vim/after/syntax/tex/ directory (make it if it doesn't exist)
let b:loaded_lstlisting  = "v1b"
syn region texZone	start="\\begin{lstlisting}" end="\\end{lstlisting}\|%stopzone\>"
syn region texZone	start="\\lstinputlisting" end="{\s*[a-zA-Z/.0-9_^]\+\s*}"
