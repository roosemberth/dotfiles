#/usr/bin/env sh

DIR="$(mktemp -d -p /run/user/$(id -u)/)"
cd "$DIR"

export XDG_CONFIG_HOME=.
export XDG_DATA_HOME=.
export XDG_CACHE_HOME=.

timeout 60 shutter --disable_systray -s -e -n -o /tmp/export.png > /dev/null

if [ $? != 0 ]; then
  notify-send -u low 'Screenshot' "Failed to capture screenshot."
else
  curl -F 'file=@/tmp/export.png;type=image/png' -H 'Expect:' https://paste.gnugen.ch | xclip -selection clipboard
  notify-send -u low 'Screenshot' "Screenshot savec to /tmp/export.png and gnupaste link copied to clipboard\!"
fi

rm -fr "$DIR"
