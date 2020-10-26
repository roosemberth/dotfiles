#!/usr/bin/env zsh
# (C) 2020 - Roosembert Palacios <roosemberth@posteo.ch>
# Released under CC BY-NC-SA License: https://creativecommons.org/licenses/
# Based on my own previous zsh configuration, available on gitlab, under tag
# prereset-2020.

# -----------------------------------------------------------------------------
# Profiling. There's small related section at the end of this file. {{{
# See http://stackoverflow.com/a/4351664/2418854
if [ ! -z "$ZSH_PROFILING" ]; then
    # Set the trace prompt to include seconds, nanoseconds, script name and
    # line number. This is GNU date syntax; by default Macs ship with the BSD
    # date program, which is not compatible.
    PS4='+$(date "+%s:%N") %N:%i> '
    # Save stderr fd into fd 3 and redirect stderr (including trace output) to
    # a file with the script's PID as an extension.
    exec 3>&2 2>/tmp/zshprofiling.$$
    # Set options to turn on tracing and expansion of commands contained in the
    # prompt.
    setopt xtrace prompt_subst
fi
# }}}

export EDITOR="$(command -v vim)"
export VISUAL="$(command -v vim) -O"
export PAGER="$(command -v less) -j.3"

if [ "$XDG_SESSION_TYPE" = "tty" ]; then
    export GPG_TTY="$(tty)"
else
    unset GPG_TTY
fi

# Honor the XDG directory specification as best as possible. {{{
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
if [ -z "$XDG_RUNTIME_DIR" ]; then
    echo "Warning: XDG_RUNTIME_DIR is not set. Fallback to ~/.local/run" >&2
    export XDG_RUNTIME_DIR="~/.local/run"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        if mkdir -p "$XDG_RUNTIME_DIR"; then
            chmod 700 "$XDG_RUNTIME_DIR"
        else
            echo "Could not create fallback XDG_RUNTIME_DIR." >&2
            unset XDG_RUNTIME_DIR
        fi
    fi
fi
## Not part of the FHS standard, but usefull nonetheless
export XDG_LOG_HOME="${XDG_LOG_HOME:-$HOME/.local/var/log}"
# }}}

# Make sure required zsh directories exists:
test -d "$XDG_CACHE_HOME/zsh" || mkdir -p "$XDG_CACHE_HOME/zsh"
test -d "$XDG_DATA_HOME/zsh" || mkdir -p "$XDG_DATA_HOME/zsh"
test -d "$XDG_LOG_HOME/zsh" || mkdir -p "$XDG_LOG_HOME/zsh"

# Nix and NixOS-specific configuration {{{
if [ -d /run/current-system/sw/share/zsh/site-functions ]; then
  fpath+=(/run/current-system/sw/share/zsh/site-functions)
fi
if [ -d ~/.nix-profile/share/zsh/site-functions ]; then
  fpath+=(~/.nix-profile/share/zsh/site-functions)
fi
if command -v fzf-share &> /dev/null; then
  source "$(fzf-share)/completion.zsh"
  source "$(fzf-share)/key-bindings.zsh"
fi
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi
# }}}

# -----------------------------------------------------------------------------
# Completion configuration {{{
zstyle ':completion:*' add-space file
zstyle ':completion:*' ambiguous true
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
zstyle ':completion:*' completer _complete _correct _extensions _ignored \
                                 _match _prefix
zstyle ':completion:*' format "[%{$fg_bold[default]%}%d%{$reset_color%}]"
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd
zstyle ':completion:*' gain-privileges true
zstyle ':completion:*' list-dirs-first true
zstyle ':completion:*' list-suffixes true
zstyle ':completion:*' separate-sections true
zstyle ':completion:*' show-ambiguity true
zstyle ':completion:*' show-completer true
zstyle ':completion:*' single-ignored true
zstyle ':completion:*' use-ips true
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kubectl:*' call-command true

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
# }}}

# -----------------------------------------------------------------------------
# Antigen {{{
# Do not run any antigen integrations if we are root.
if [ $(id -u) != 0 ]; then
    # install if not installed
    if [ ! -f $XDG_CACHE_HOME/zsh/antigen/antigen.zsh ]; then
        if [ ! -d "$XDG_CACHE_HOME/zsh/antigen" ]; then
           mkdir -p "$XDG_CACHE_HOME/zsh/antigen"
        fi
        timeout 10 curl -L "https://git.io/antigen" \
                        -o "$XDG_CACHE_HOME/zsh/antigen/antigen.zsh" \
        || echo "Problem obtaining antigen script."
    fi

    # antigen.zsh will automatically download any required bundles.
    if [ -f "$XDG_CACHE_HOME/zsh/antigen/antigen.zsh" ] \
            && command -v git >/dev/null 2>&1; then
        export ADOTDIR="$XDG_CACHE_HOME/zsh/antigen"
        export ANTIGEN_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompdump"
        export ANTIGEN_CACHE="$XDG_CACHE_HOME/zsh/antigen/cache"
        export ANTIGEN_LOG="$XDG_LOG_HOME/zsh/antigen"

        source "$XDG_CACHE_HOME/zsh/antigen/antigen.zsh"

        antigen bundle zsh-users/zsh-completions src
        antigen bundle zsh-users/zsh-autosuggestions
        antigen bundle zsh-users/zsh-syntax-highlighting
        antigen bundle peterhurford/git-it-on.zsh
        antigen bundle ninrod/pass-zsh-completion
        antigen bundle Vifon/deer

        antigen apply
    fi
fi

# -----------------------------------------------------------------------------
# Options {{{
setopt beep
setopt extended_history
setopt hist_ignore_all_dups
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_lex_words
setopt inc_append_history
setopt magic_equal_subst
setopt notify
setopt prompt_subst  # Allow substitutions as part of prompt format string
setopt pushd_silent
setopt pushd_to_home
setopt sh_word_split  # Handle IFS as SH

unsetopt bang_hist  # Don't expand history elements with '!' character
# }}}

# -----------------------------------------------------------------------------
# Misc {{{
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export HISTSIZE=100000          # maximum history size in terminal's memory
export SAVEHIST=100000000       # maximum size of history file

zshaddhistory() {  # Filter commands going to the history
    line=${1%%$'\n'}
    case "$line" in
        fg|bg) return 1 ;;
    esac
}
# }}}

# -----------------------------------------------------------------------------
# Prompt behaviour {{{
bindkey -v  # Use vim mode
bindkey -M viins ''    backward-delete-char # <Backspace>
bindkey -M viins '[3~' delete-char      # <Delete>
bindkey -M viins ''    beginning-of-line
bindkey -M viins ''    end-of-line
bindkey -M viins ''    kill-line
bindkey -M viins ''    up-line-or-history
bindkey -M viins ''    down-line-or-history
bindkey -M viins ''    backward-kill-line
bindkey -M viins ''    vi-backward-kill-word
bindkey -M viins '^@'    vi-forward-word  # C-<Space>
bindkey -M viins ''    push-input       # Save current line for later

# ranger-like path search
autoload -U deer
zle -N deer
bindkey -M viins '' deer

# Use vim to edit command lines:
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

autoload -Uz vcs_info

zstyle ':vcs_info:*' enable git cvs svn
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' use-prompt-escapes true

zstyle ':vcs_info:git*' stagedstr '%F{yellow}'
zstyle ':vcs_info:git*' unstagedstr '%F{red}'
zstyle ':vcs_info:git*' formats '%F{green}%c%u[%b]%f'
zstyle ':vcs_info:git*' actionformats '%F{green}%c%u[%b%F{cyan}|%a%c%u]%f'
zstyle ':vcs_info:git*+set-message:*' hooks git-colors

+vi-git-colors() {
    [[ $(git rev-parse --is-inside-work-tree 2>&1) == 'true' ]] || return

    if git status --porcelain | grep -qE '^ M'; then
        hook_com[unstaged]='%F{red}'
    elif git status | awk '/^$/{exit} {print $0}' | grep -qi 'ahead'; then
        hook_com[unstaged]='%F{cyan}'
    elif git status | awk '/^$/{exit} {print $0}' | grep -qi 'behind'; then
        hook_com[unstaged]='%F{blue}'
    elif git status | awk '/^$/{exit} {print $0}' | grep -qi 'diverged'; then
        hook_com[unstaged]='%F{magenta}'
    fi
}

build_prompt() {
    PROMPT=''
    PROMPT+="%(1j.%F{black}%K{white} %j %k%f.)"  # Background jobs

    vcs_info && PROMPT+="${vcs_info_msg_0_} "

    [ -n "$SSH_CONNECTION" ] && PROMPT+="%F{magenta}%M:%f"
    [ -n "$(ip netns identify 2>/dev/null)" ] && \
        PROMPT+="%F{white}%K{blue}$(ip netns identify 2>/dev/null)%k%f"

    PROMPT+='%F{blue}%~%f '

    [ -n "$VIRTUAL_ENV" ] && PROMPT+="%F{green}÷(${VIRTUAL_ENV##*/})%f "
    [ -n "$IN_NIX_SHELL" ] && PROMPT+="%F{cyan}÷${${IN_NIX_SHELL:#1}:-nix}»%f "
}

build_rprompt() {
    RPROMPT=''
    RPROMPT+="%(?..%F{red}[%?]%f)"  # Last command's return value

    if [ -n "$timer" ]; then  # Last command's duration:
        timer_total=$((SECONDS - timer))
        timer_sec=$((timer_total % 60))
        timer_min=$((timer_total / 60 % 60))
        timer_hrs=$((timer_total / 3600 % 24))
        timer_day=$((timer_total / 86400))
        if [ $timer_total -gt 1 ]; then
            tp=''
            [ -z "$tp" ] && [ $timer_day -eq 0 ] || tp+="${timer_day}d "
            [ -z "$tp" ] && [ $timer_hrs -eq 0 ] || tp+="${timer_hrs}h "
            [ -z "$tp" ] && [ $timer_min -eq 0 ] || tp+="${timer_min}m "
            [ -z "$tp" ] && [ $timer_sec -eq 0 ] || tp+="${timer_sec}s"
            RPROMPT+=" %F{green}$tp%f"
            unset tp
        fi
        unset timer_total timer_sec timer_min timer_hrs timer_day timer
    fi
}

preexec() {
    timer=${timer:-$SECONDS}
    unset PROMPT
    unset RPROMPT
}

precmd() {
    build_prompt
    build_rprompt
}

precmd
# }}}

# -----------------------------------------------------------------------------
# functions and aliases {{{
function aps(){
    ps aux | grep -v grep | grep -i "$1"
}

function ctmp(){
    DIR="$(mktemp -dp ${XDG_RUNTIME_DIR:-/run/user/$(id -u)/})"
    command -v lsof &>/dev/null && (
        while [ -d "$DIR" ]; do
            sleep 5
            if [ -z "\$(lsof +d '$DIR' 2>/dev/null)" ] \
                && [ -z "\$(lsof +D '$DIR' 2>/dev/null)" ]; then
                rm -fr "$DIR"
            fi
        done
    )&!
    [ -d "${DIR%/*}/latest-ctmp" ] && rm "${DIR%/*}/latest-ctmp"
    ln -sf "$DIR" "${DIR%/*}/latest-ctmp"
    pushd "$DIR"
}

function cltmp(){
  pushd "/run/user/$(id -u)/latest-ctmp/"
}

alias .....="cd ../../../.."
alias ....="cd ../../.."
alias ...="cd ../.."
alias ..="cd .."
alias cdg='cd "$(git rev-parse --show-toplevel)"'
alias cp='cp -i'
alias df='df -h'
alias l='ls -vCF'
alias ll='ls -valFh'
alias ls='ls --color=auto'
alias mv='mv -i'
alias rlf='readlink -f'
alias rm='rm --one-file-system'
alias view="${EDITOR:=vim} -R"
alias wtf='dmesg | tail -n 20'
# }}}

# -----------------------------------------------------------------------------
# Profiling closure. See profiling section at the beginning of this file {{{
if [ ! -z "$ZSH_PROFILING" ]; then
    # turn off tracing
    unsetopt xtrace
    # restore stderr to the value saved in FD 3
    exec 2>&3 3>&-
fi
# }}}

# vim:expandtab:shiftwidth=4:tabstop=4:colorcolumn=80
