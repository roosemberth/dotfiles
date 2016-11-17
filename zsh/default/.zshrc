#!/usr/bin/env zsh
# Zsh default configuration file
#
# (C) 2016 - Roosembert Palacios <roosembert.palacios@epfl.ch> 
# Released under CC BY-NC-SA License: https://creativecommons.org/licenses/


# Profiling: http://stackoverflow.com/a/4351664/2418854 there's a hook at the end aswell.
if [ ! -z "$ZSH_PROFILING" ]; then
	# set the trace prompt to include seconds, nanoseconds, script name and line number
	# This is GNU date syntax; by default Macs ship with the BSD date program, which isn't compatible
	PS4='+$(date "+%s:%N") %N:%i> '
	# save file stderr to file descriptor 3 and redirect stderr (including trace 
	# output) to a file with the script's PID as an extension
	exec 3>&2 2>/tmp/startlog.$$
	# set options to turn on tracing and expansion of commands contained in the prompt
	setopt xtrace prompt_subst
fi

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate _prefix
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# zstyle :compinstall filename "$XDG_CONFIG_HOME/zsh/default/.zshrc"

# This pushes current cmd to a stack so It'll let me run something else and restores the cmd on the next shell prompt
bindkey -M viins "^B" push-input
bindkey -M viins "^R" vi-forward-word				# accept partial suggestions

autoload -Uz compinit promptinit
compinit
promptinit
# End of lines added by compinstall

# This will allow "Special dirs" (./ and ../) to be available as autocomplete
zstyle ':completion:*' special-dirs true

HISTFILE=~/.histfile
HISTSIZE=10000000
SAVEHIST=10000000
setopt EXTENDED_HISTORY APPEND_HISTORY BEEP NOTIFY HIST_IGNORE_DUPS INC_APPEND_HISTORY

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

# Antigen {{{
# install if not installed
[ -f $XDG_CONFIG_HOME/zsh/antigen.zsh ] \
	|| curl -L "https://raw.githubusercontent.com/zsh-users/antigen/master/antigen.zsh" -o "$XDG_CONFIG_HOME/zsh/antigen.zsh" \
	|| echo "Problem obtaining antigen script"

if [ -f $XDG_CONFIG_HOME/zsh/antigen.zsh ]; then
	source $XDG_CONFIG_HOME/zsh/antigen.zsh

	antigen bundle robbyrussell/oh-my-zsh plugins/git
	antigen bundle robbyrussell/oh-my-zsh plugins/systemd

	antigen bundle zsh-users/antigen
	antigen bundle zsh-users/zsh-completions src
	antigen bundle zsh-users/zsh-autosuggestions
	antigen bundle zsh-users/zsh-syntax-highlighting
fi

# }}}  -------------------------------------------------------------------------

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
	ADDITIONAL_FUNCTIONS=$(find -L $XDG_CONFIG_HOME/zsh/functions -type f -iname "*.func")
	
	for newFunction in ${ADDITIONAL_FUNCTIONS}; do
		source ${newFunction}
		if [[ $? != 0 ]]; then
			print "Error processing additional function ${newFunction}" 1>&2
		fi
	done
	unset ADDITIONAL_FUNCTIONS
fi

# }}}  -------------------------------------------------------------------------

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
	local aliasTarget="$(eval print ${1#*=})"
	local aliasTargetBinary="${aliasTarget%% *}"
	[ -z "$aliasTargetBinary" ] && print "wtf? Tryed to bind empty alias: $1" && return
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
	ALIAS_GRPS=$(find -L $XDG_CONFIG_HOME/zsh/aliases -type f -iname "*.aliasgrp")

	for ALIAS_GRP in ${ALIAS_GRPS}; do
		LOG_FILENAME="$(mktemp)"
		. ${ALIAS_GRP} > $LOG_FILENAME
		if [ -n "$(cat $LOG_FILENAME)" ]; then
			print "Error processing additional alias group ${ALIAS_GRP}:" 1>&2
			cat $LOG_FILENAME
		fi
		[ -f "$LOG_FILENAME" ] && rm $LOG_FILENAME
	done
	unset ALIAS_GRPS
else
	echo "Warning, I was not able to find $XDG_CONFIG_HOME/zsh/aliases"
fi
# }}}  -------------------------------------------------------------------------

# daemons {{{
# ssh-agent
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/tmp}/ssh-agent-$(id -u)-socket"
# which ssh &>/dev/null && which ssh-agent &>/dev/null && [ -f "${SSH_AUTH_SOCK}" ]

# }}}  -------------------------------------------------------------------------

[ -f /usr/lib/ruby/gems/2.3.0/gems/tmuxinator-0.7.0/completion/tmuxinator.zsh ] \
	&& source /usr/lib/ruby/gems/2.3.0/gems/tmuxinator-0.7.0/completion/tmuxinator.zsh

[ -e $XDG_CONFIG_HOME/bin ] \
	&& export PATH="$(readlink -f $XDG_CONFIG_HOME/bin):$PATH"

[ -e $XDG_DATA_HOME/bin ] \
	&& export PATH="$(readlink -f $XDG_DATA_HOME/bin):$PATH"

[ -e $HOME/.local/bin ] \
	&& export PATH="$(readlink -f $HOME/.local/bin):$PATH"

# gem install --user <gem>
[ -e $HOME/.gem/ruby/2.3.0/bin ] \
	&& export PATH="$(readlink -f $HOME/.gem/ruby/2.3.0/bin):$PATH"

[ -f $XDG_DATA_HOME/zsh/.zshrc.local ] \
	&& source $XDG_DATA_HOME/zsh/.zshrc.local

if [ ! -z "$ZSH_PROFILING" ]; then
	# turn off tracing
	unsetopt xtrace
	# restore stderr to the value saved in FD 3
	exec 2>&3 3>&-
fi
