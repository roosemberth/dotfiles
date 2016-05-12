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
        zsh*|tmux*|bash*)
            exec "$1"
            ;;
        *)
            cat << SDA | sh &! 
$1
SDA
            exit
            ;;
    esac
}