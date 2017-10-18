#!/usr/bin/env zsh
# Zsh default configuration file
#
#     2013-2017 - «ayekat»
# (C) 2016-2017 - Roosembert Palacios <roosembert.palacios@epfl.ch> 
# Released under CC BY-NC-SA License: https://creativecommons.org/licenses/

# ------------------------------------------------------------------------------
# Profiling: http://stackoverflow.com/a/4351664/2418854 there's a hook at the end aswell. {{{
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
# }}}
# ------------------------------------------------------------------------------

# Shell-agnostic configuration:
. $XDG_CONFIG_HOME/sh/config

# ------------------------------------------------------------------------------
# Local variables {{{
if [ ! -z "$NO_NET" ]; then
    alias doNetOps=false
else
    alias doNetOps=true
fi
# }}}
# ------------------------------------------------------------------------------
# COMPLETION {{{

# Make sure the zsh cache directory exists:
test -d "$XDG_CACHE_HOME/zsh" || mkdir -p "$XDG_CACHE_HOME/zsh"

# The following lines were added by compinstall

#zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate _prefix
#zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' format "[%{$fg_bold[default]%}%d%{$reset_color%}]"
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd
zstyle ':completion:*' preserve-prefix '//[^/]##/'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle :compinstall filename "${XDG_CONFIG_HOME}/zsh/.zshrc"

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Do not autocomplete when ambiguous (bash-like):
#setopt no_auto_menu

# Print 'completing ...' when completing:
expand-or-complete-with-dots () {
	printf "$fg[blue] completing ...$reset_color\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
	zle expand-or-complete
	zle redisplay
}
zle -N expand-or-complete-with-dots
bindkey "^I" expand-or-complete-with-dots

# }}}
# ------------------------------------------------------------------------------
# Antigen {{{
# Root?
if [ $(id -u) != 0 ]; then
    # install if not installed
    if [ ! -f ${XDG_CACHE_HOME}/zsh/antigen/antigen.zsh ]; then
        if [ doNetOps ]; then
            test -d "$XDG_CACHE_HOME/zsh/antigen" || mkdir -p "$XDG_CACHE_HOME/zsh/antigen"
            curl -L "https://git.io/antigen" -o "${XDG_CACHE_HOME}/zsh/antigen/antigen.zsh" \
                -o "${XDG_CACHE_HOME}/zsh/antigen/antigen.zsh" \
            || echo "Problem obtaining antigen script"
        fi
    fi

    # Make sure the zsh log directory exists:
    test -d "${XDG_LOG_HOME}" || mkdir -p "${XDG_LOG_HOME}"

    # If antigen.zsh was just downloaded it will download its bundles, else it will just load them
    if [ -f ${XDG_CACHE_HOME}/zsh/antigen/antigen.zsh ] && which "git" >/dev/null 2>&1; then
        export ADOTDIR="${XDG_CACHE_HOME}/zsh/antigen/repos"
        #export ANTIGEN_COMPDUMPFILE="$XDG_CACHE_HOME/zsh/zcompdump"
        export _ANTIGEN_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"
        export _ANTIGEN_CACHE="${XDG_CACHE_HOME}/zsh/antigen/cache"
        export _ANTIGEN_LOG="${XDG_LOG_HOME}/antigen"

        source ${XDG_CACHE_HOME}/zsh/antigen/antigen.zsh

        antigen bundle zsh-users/zsh-completions src
        antigen bundle zsh-users/zsh-autosuggestions
        antigen bundle zsh-users/zsh-syntax-highlighting

        antigen apply
    fi
fi

# }}}  -------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# LOOK & FEEL {{{

# Handle IFS correctly:
setopt SH_WORD_SPLIT BEEP NOTIFY

# FIXME: Use build_prompt()....
# This "marks" the terminal by exporting an non empty variable 
# so if we nest, we "mark" the nest. Skip alias aliases
#\alias MARK="MARK="yes" "
# Check if we're in a nested shell, and add to PS1
#if [[ "$(ps hp $PPID -o comm)" == "$0" ]]; then
#    if [[ -z "$MARK" ]]; then
#        export PS1="-${PS1}"
#    else
#        export PS1="|${PS1}"
#        export MARK=""
#    fi
#fi

# }}}
# ------------------------------------------------------------------------------
# PROMPT {{{

# Enable colours:
autoload -U colors && colors

# Allow shell substitutions as part of prompt format string:
setopt prompt_subst

# Define prompt colours:
pc_vim_normal="$fg[black]$bg[green]"
pc_vim_insert="$fg[green]$bg[blue]"
pc_time="$fg[green]"
pc_retval_bad="$fg_bold[red]"
pc_retval_good="$fg[black]"

# Define vim mode strings:
vim_mode_normal='CMD'
vim_mode_insert='INS'
vim_mode=$vim_mode_insert

# Assist functions {{{
build_netns_prompt()
{
    local ns_name="$(ip netns identify 2>/dev/null)"
    echo "$ns_name"
}
#}}}

build_prompt() #{{{
{
	PROMPT=''

	# Background jobs:
	PROMPT+="%(1j.%{$pc_jobs%} %j %{$reset_color%}.)"

	# Vim mode:
	if [ "$vim_mode" = "$vim_mode_normal" ]; then
		pc_vim="$pc_vim_normal"
	else
		pc_vim="$pc_vim_insert"
	fi
	PROMPT+="%{$pc_vim%} ${vim_mode:-$vim_mode_insert} %{$reset_color%} "

	# VCS (watched):
	if [ -z "$1" ]; then
		VCS_PROMPT=''
		_vcs_clean=1
		_build_vcs_prompt() {
			vcs_update "$1"
			case "$vcs_state" in (ahead|dvrgd|ready|dirty|merge)
				if [ $_vcs_clean -eq 1 ]; then
					VCS_PROMPT+="%{$(printf "\033[34m")%}["
					_vcs_clean=0
				fi
				case "$vcs_state" in
					ahead) VCS_PROMPT+="%{$pc_vcs_ahead%}" ;;
					dvrgd) VCS_PROMPT+="%{$pc_vcs_dvrgd%}" ;;
					ready) VCS_PROMPT+="%{$pc_vcs_ready%}" ;;
					dirty) VCS_PROMPT+="%{$pc_vcs_dirty%}" ;;
					merge) VCS_PROMPT+="%{$pc_vcs_merge%}" ;;
				esac
				VCS_PROMPT+="$2"
			esac
		}
		_build_vcs_prompt "$HOME/dotfiles" 'd'
		_build_vcs_prompt "/Storage/Media/Music" 'm'
		_build_vcs_prompt "$XDG_DATA_HOME/pass" 'p'
		if [ $_vcs_clean -eq 0 ]; then
			VCS_PROMPT+="%{$(printf "\033[34m")%}]%{$reset_color%} "
		fi
		unset -f _build_vcs_prompt
		unset _vcs_clean
	fi
	PROMPT+="$VCS_PROMPT"

	# VCS (PWD):
	vcs_update "$(pwd)"
	if [ -n "$vcs_state" ]; then
		case "$vcs_state" in
			huge)  PROMPT+="%{$pc_vcs_huge%}"  ;;
			clean) PROMPT+="%{$pc_vcs_clean%}" ;;
			ahead) PROMPT+="%{$pc_vcs_ahead%}" ;;
			dvrgd) PROMPT+="%{$pc_vcs_dvrgd%}" ;;
			ready) PROMPT+="%{$pc_vcs_ready%}" ;;
			dirty) PROMPT+="%{$pc_vcs_dirty%}" ;;
			merge) PROMPT+="%{$pc_vcs_merge%}" ;;
		esac
		PROMPT+="[$vcs_branch]%{$reset_color%} "
	fi

	# Hostname (if SSH):
	[ -n "$SSH_CONNECTION" ] && PROMPT+="%{$pc_host%}%M:%{$reset_color%}"

	# Network namespace
    [ -n "$(ip netns identify 2>/dev/null)" ] && PROMPT+="%{$fg[white]%}%{$bg[blue]%}$(build_netns_prompt)%{$reset_color %}"

	# PWD:
	PROMPT+="%{$pc_pwd%}%~%{$reset_color%} "

	# Root?
	if [ $(id -u) = 0 ]; then
		PROMPT+="%{$pc_prompt%}#%{$reset_color%} "
	fi

	export PROMPT
}
#}}}

build_rprompt() #{{{
{
	RPROMPT=''

	# Last command's return value:
	RPROMPT+="%(?..%{$pc_retval_bad%}[%?]%{$reset_color%})"

	# Last command's duration:
	if [ -n "$timer" ]; then
		timer_total=$(($SECONDS - $timer))
		timer_sec=$(($timer_total % 60))
		timer_min=$(($timer_total / 60 % 60))
		timer_hour=$(($timer_total / 3600 % 24))
		timer_day=$(($timer_total / 86400))
		if [ ${timer_total} -gt 1 ]; then
			tp=''
			[ -z "$tp" ] && [ $timer_day -eq 0 ]  || tp+="${timer_day}d "
			[ -z "$tp" ] && [ $timer_hour -eq 0 ] || tp+="${timer_hour}h "
			[ -z "$tp" ] && [ $timer_min -eq 0 ]  || tp+="${timer_min}m "
			[ -z "$tp" ] && [ $timer_sec -eq 0 ]  || tp+="${timer_sec}s"
			RPROMPT+=" %{$pc_time%}${tp}%{$reset_color%}"
			unset tp
		fi
		unset timer_total timer_sec timer_min timer_hour timer_day timer
	fi

	export RPROMPT
}
#}}}

preexec()
{
	timer=${timer:-$SECONDS}
	unset PROMPT
	unset RPROMPT
}

precmd()
{
	build_prompt
	build_rprompt
}

precmd

# }}}
# ------------------------------------------------------------------------------
# VIM {{{

# Use vim mode, but keep handy emacs keys in insert mode:
bindkey -v
bindkey -M viins ''    backward-delete-char
bindkey -M viins '[3~' delete-char
bindkey -M viins ''    beginning-of-line
bindkey -M viins ''    end-of-line
bindkey -M viins ''    kill-line
bindkey -M viins ''    up-line-or-history
bindkey -M viins ''    down-line-or-history
bindkey -M viins ''    backward-kill-line
bindkey -M viins ''    backward-kill-word
bindkey -M viins ''    vi-forward-word  # accept partial suggestions
bindkey -M viins '[Z'    vi-forward-word  # accept partial suggestions
bindkey -M viins ''    push-input       # I forgot to type something before!

bindkey -M viins ' '   end-of-line

# Use vim to edit command lines:
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

# Handler for mode change:
zle-keymap-select() {
	vim_mode="${${KEYMAP/vicmd/${vim_mode_normal}}/(main|viins)/${vim_mode_insert}}"
	build_prompt mode
	zle reset-prompt
}
zle -N zle-keymap-select

# Handler for after entering a command (reset to insert mode):
zle-line-finish() {
	vim_mode=$vim_mode_insert
	build_prompt mode
}
zle -N zle-line-finish

# ^C puts us back in insert mode; repropagate to not interfere with dependants:
TRAPINT() {
	vim_mode=$vim_mode_insert
	build_prompt
	return $((128 + $1))
}

# Delay for key sequences:
KEYTIMEOUT=1

# }}}
# ------------------------------------------------------------------------------
# FUNCTIONS {{{
# "Include" custom shell function groups.
# They need to have a proper function declaration
#
# ------------------------------------------------------------------------------
# function myCoolFunc(){
#	# cool function code here
# }
# function myCoolerFunc(){
#	# cooler function code here
# }
# ----------------------------- file: $XDG_CONFIG_HOME/zsh/functions/myFunGrp.fg
#
# This functions can be located in subdirectories aswell
# but only the files ending with '.func' will be included. 

if [ -d "$XDG_CONFIG_HOME/zsh/functions" ]; then
	ADDITIONAL_FUNCTIONS=$(find -L $XDG_CONFIG_HOME/zsh/functions -type f -iname "*.fg")
	
	for newFunction in ${ADDITIONAL_FUNCTIONS}; do
		source ${newFunction}
		if [[ $? != 0 ]]; then
			print "Error processing additional function ${newFunction}" 1>&2
		fi
	done
	unset ADDITIONAL_FUNCTIONS
fi

# }}}
# ------------------------------------------------------------------------------
# ALIASES {{{
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
		[ -f "$LOG_FILENAME" ] && rm -f $LOG_FILENAME
	done
	unset ALIAS_GRPS
else
	echo "Warning, I was not able to find $XDG_CONFIG_HOME/zsh/aliases"
fi
# }}}  -------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# HISTORY {{{

# Make sure the zsh log directory exists:
test -d "$XDG_DATA_HOME/zsh" || mkdir -p "$XDG_DATA_HOME/zsh"

setopt inc_append_history       # immediately append history to history file
setopt hist_ignore_dups         # ignore duplicate commands
setopt hist_ignore_space        # ignore commands with leading space
setopt extended_history

export HISTFILE="$XDG_DATA_HOME/zsh/zhistory"
export HISTSIZE=100000          # maximum history size in terminal's memory
export SAVEHIST=1000000         # maximum size of history file

# prevent commands from entering the history
zshaddhistory() {
	line=${1%%$'\n'}
	case "$line" in
		fg|bg) return 1 ;;
	esac
}

# }}}
# ------------------------------------------------------------------------------


if [ ! -z "$ZSH_PROFILING" ]; then
	# turn off tracing
	unsetopt xtrace
	# restore stderr to the value saved in FD 3
	exec 2>&3 3>&-
fi

# Souce local overrides
[ -f $XDG_DATA_HOME/zsh/.zshrc.local ] \
	&& source $XDG_DATA_HOME/zsh/.zshrc.local

[ -f ~/.zshrc.local ] \
	&& source ~/.zshrc.local
