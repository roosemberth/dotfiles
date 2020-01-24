if [ -n "$OLD_ZDOTDIR" ]; then
    [ -f "$OLD_ZDOTDIR"/.zshrc ] && source "$OLD_ZDOTDIR"/.zshrc
fi

preexec(){
    if [ -n "$OLD_ZDOTDIR" ]; then
        export ZDOTDIR="$OLD_ZDOTDIR"
        unset OLD_ZDOTDIR
    else
        unset ZDOTDIR
    fi

    case "$1" in
        zsh*|tmux*)
            exec tmux
            ;;
        bash*)
            exec "$1"
            ;;
        *)
            cat << SDA | zsh -s &!
$1
SDA
            exit
            ;;
    esac
}

if zle -l | egrep '^fzf-history-widget' &> /dev/null; then
  function zle-line-init {
    zle fzf-history-widget
  }
  zle -N zle-line-init
fi
