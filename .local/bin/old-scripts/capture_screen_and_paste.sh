#!/usr/bin/env bash
# Written by Orbstheorem while drinking coffee a cold morning at epfl
set -e

sleep 0.2 # https://unix.stackexchange.com/a/192757
scrot -q100 -m -s -z /tmp/export.png -e 'pastegnugen.pl $f' | awk '{print $NF}'
