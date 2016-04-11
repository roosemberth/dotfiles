# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate _prefix
zstyle :compinstall filename "$XDG_CONFIG_HOME/zsh/default/.zshrc"

# This will import zsh-syntax.completition
path_syntax=/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -e "$path_syntax" ] && . "$path_syntax"
unset path_syntax

# This pushes current cmd to a stack so It'll let me run something else and restores the cmd on the next shell prompt
bindkey "^B" push-input

autoload -Uz compinit promptinit
compinit
promptinit
# End of lines added by compinstall

# This will allow "Special dirs" (./ and ../) to be available as autocomplete
zstyle ':completion:*' special-dirs true

HISTFILE=~/.histfile
HISTSIZE=1000000
SAVEHIST=1000000
setopt appendhistory beep notify HIST_IGNORE_DUPS
# vim mode
bindkey -v

# Edit current command in editor
autoload edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

export EDITOR="vim"

# This "marks" the terminal by exporting an non empty variable 
# so if we nest, we "mark" the nest. Skip alias aliases
\alias MARK="MARK="yes" "

# This will fix broken (bash imported) scripts which use 
# "for var in ${list of space separated variables goes here}" loops
setopt sh_word_split

# Check if we're in a nested shell, and add to PS1
if [[ "$(ps hp $PPID -o comm)" == "$0" ]]; then 
	if [[ -z "$MARK" ]]; then
		export PS1="-${PS1}"
	else 
		export PS1="|${PS1}"
		export MARK=""
	fi
fi

# functions {{{
# "Include" custom shell functions.
# They need to have a proper function declaration
#
# ------------------------------------------------------------------------------
# function myfunc(){
#	# cool function code here
# }
# ----------------------------- file: $XDG_CONFIG_HOME/zsh/functions/myfunc.func
#
# This functions can be located in subdirectories aswell
# but only the files ending with '.func' will be included. 

if [ -d "$XDG_CONFIG_HOME/zsh/functions" ]; then
    ADDITIONAL_FUNCTIONS=$(find $XDG_CONFIG_HOME/zsh/functions -type f -iname "*.func")
    
    for newFunction in ${ADDITIONAL_FUNCTIONS}; do
    	source ${newFunction}
    	if [[ $? != 0 ]]; then
    		print "Error processing additional function ${newFunction}" 1>&2
    	fi
    done
    unset ADDITIONAL_FUNCTIONS
fi

# Space for small functions which do not merite to be in a single file ---------
function reload(){
	source ${ZDOTDIR:-~}/.zshrc
}

function whoIsMyParent(){
	# Grep is just for coloring...
	ps hu $PPID | grep $PPID
}

function aps(){
	ps aux | grep -v grep | grep -i $1
}

function lastCommand(){
	history | tail -n 1 | sed 's/^[ 0-9]*//'
}

function launch(){
	cat << SDA | sh &! exit
$@
SDA

}
# }}} --------------------------------------------------------------------------

# aliases {{{
# "Include" custom shell alias groups.
# They should contain legal alias declarations
#
# ------------------------------------------------------------------------------
# alias ll='ls -alFh'
# alias la='ls -A'
# alias l='ls -CF'
# -------------------------- file: $XDG_CONFIG_HOME/zsh/aliases/default.aliasgrp
#
# This alias group files can be located in subdirectories aswell
# but only the files ending with '.aliasgrp' will be included. 

# Safer alias function
safeAlias(){
    local aliasTarget=$(eval print ${1#*=})
    local aliasTargetBinary=${aliasTarget%% *}
    print $aliasTarget >> /tmp/log
    print $aliasTargetBinary >> /tmp/log
    if [ -z "$(whence "$aliasTargetBinary")" ]; then
        print "Couldn't resolve Alias Target: \"$aliasTargetBinary\"" 1>&2
        return
    fi
    # It's fine, invoke real alias function
    \alias "$1"
}
# Override alias to have a safer alias
alias alias='safeAlias'

if [ -d "$XDG_CONFIG_HOME/zsh/aliases" ]; then
    ALIAS_GRPS=$(find $XDG_CONFIG_HOME/zsh/aliases -type f -iname "*.aliases")
    
    for ALIAS_GRP in ${ALIAS_GRPS}; do
        MSG="$(source ${ALIAS_GRP})"
    	if [ -n "$MSG" ]; then
    		print "Error processing additional alias group ${ALIAS_GRP}:" 1>&2
            print $MSG
    	fi
    done
    unset ALIAS_GRPS
fi
# }}} -----------------------------------#---------------------------------------

# This will load local "Host-dependant" zsh config files, so we won't polute git repo :)
if [[ -e ~/.zshrc.local ]]; then
	source ~/.zshrc.local
fi

[ -f /usr/lib/ruby/gems/2.3.0/gems/tmuxinator-0.7.0/completion/tmuxinator.zsh ] \
    && source /usr/lib/ruby/gems/2.3.0/gems/tmuxinator-0.7.0/completion/tmuxinator.zsh

[ -e ~/dotfiles/GPScripts ] && export PATH="$(readlink -f ~/dotfiles/GPScripts):$PATH"
