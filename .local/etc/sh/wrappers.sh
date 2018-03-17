#!/bin/sh
# Written by Roosembert Palacios from the night of Mar 15th through dawn

################################################################################
# Wrapper logic
################################################################################
GENERATOR_NAME="wrappers"
DEST_DIR="${XDG_RUNTIME_DIR:-${HOME}/run}/bin"
DEST_PATH="${DEST_DIR}/${GENERATOR_NAME}"

mkdir -p "$DEST_DIR"
# Remove previous wrappers without removing the folder.
for file in $(ls -v1 "$DEST_DIR"); do
  rm -f "$DEST_DIR/$file"
done

prepare()
(
  cat << end > "$DEST_PATH"
#!/bin/sh

find_real_exec(){
  PATH="\$(echo ":\$PATH:" | sed -e "s|:\\(${DEST_DIR}/\?:\\)\\+|:|g;s|^:||;s|:\$||")" which "\$1"
}
end

  chmod +x "$DEST_PATH"
)

construct()
(
  APP="$1"

  read PREPEND
  read INTERPOSE
  read APPEND
  printf "wrapped_%s()(\n%s \$(find_real_exec %s) %s \$@ %s\n)\n" "$APP" "$PREPEND" "$APP" "$INTERPOSE" "$APPEND"
)

_wrap()
(
  APP="$(echo "$1" | sed 's/[^a-zA-Z0-9_.\-]/_/g')"
  echo >> "$DEST_PATH"
  construct "$APP" >> "$DEST_PATH"
  ln -sf "$DEST_PATH" "${DEST_DIR}/$APP"
)

wrap()
(
  CFG="$(cat)"
  for app in $@; do
    echo "$CFG" | _wrap "$app"
  done
)

finalise()
(
  cat <<- end >> "$DEST_PATH"

CMD="wrapped_\$(echo \$0 | sed 's|.*/||g')"
if [ "\$(command -v \$CMD)" = "\$CMD" ]; then "\$CMD" \$@; fi
end
)

# Init
prepare

################################################################################
# wrapped
################################################################################

wrap darktable <<- parw

--configdir "$XDG_DATA_HOME/darktable"
parw

wrap gimp <<- parw
GIMP2_DIRECTORY="${XDG_DATA_HOME}/gimp"
parw

wrap gpg gpg2 <<- parw
GNUPGHOME="${XDG_DATA_HOME}/gnupg"
parw

wrap npm <<- parw
NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
parw

wrap pass <<- parw
PASSWORD_STORE_DIR="${XDG_DATA_HOME}/pass"
parw

wrap python python3 <<-parw
PYTHONSTARTUP="${XDG_LIB_HOME}/python/startup.py"
parw

wrap task <<- parw
TASKRC="${XDG_CONFIG_HOME}/task/taskrc" TASKDATA="${XDG_DATA_HOME}/task"
parw

wrap timew <<- parw
TIMEWARRIORDB="$XDG_DATA_HOME/timewarrior"
parw

wrap vim <<- parw
VIMINIT="source \$XDG_CONFIG_HOME/vim/vimrc"
parw

wrap wine <<- parw
WINEPREFIX="${XDG_DATA_HOME}/wine/default"
parw

wrap wget <<- parw

--hsts-file="$XDG_CACHE_HOME/wget-hsts"
parw

# less & friends #######################
LESS_ENV="$(tr '\n' ' ' <<- pihs
LESS_TERMCAP_me="$(printf "\033[0m")"
LESS_TERMCAP_se="$(printf "\033[0m")"
LESS_TERMCAP_so="$(printf "\033[30;43m")"
LESS_TERMCAP_ue="$(printf "\033[0m")"
LESS_TERMCAP_us="$(printf "\033[32m")"
LESS_TERMCAP_mb="$(printf "\033[34m")"
LESS_TERMCAP_md="$(printf "\033[31m")"
LESS="-j.3"
LESSHISTFILE="$XDG_DATA_HOME/lesshist"
pihs
)"

wrap less man <<- parw
$LESS_ENV
parw
# /less & friends ######################

########################################

wrap cacao <<- parw
echo Hello, please have some
!
-- The end.
parw

wrap cocoa <<- parw
echo Enough cacao for you, shut it!; echo --

>/dev/null
parw

################################################################################

# Closure
finalise
