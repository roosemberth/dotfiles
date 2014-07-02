#!/bin/sh
# Actions taken at a login to bash.

# Use colorgcc to colour the gcc output:
[ -d '/usr/lib/colorgcc/bin' ] && export PATH="/usr/lib/colorgcc/bin:$PATH"

# Add user specific local bin folder:
[ -d ~/.local/bin ] && export PATH="$HOME/.local/bin:$PATH"
[ -d ~/.cabal/bin ] && export PATH="$HOME/.cabal/bin:$PATH"

# Set vim as default text editor:
which vim >/dev/null 2>&1 && { export EDITOR='vim'; export VISUAL='vim'; }

# Set less as default pager:
which less >/dev/null 2>&1 && export PAGER='less'

# Source the bash configuration:
[ -f ~/.bashrc ] && . ~/.bashrc

# This was removed, dunny why:
export XDG_CONFIG_HOME="$HOME/.config"

