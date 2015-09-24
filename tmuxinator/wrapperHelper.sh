#!/bin/bash

printf "Please enter sudo passowrd: "
read -s PASS
echo
[[ -z "$PASS" ]] && echo "Please enter a password next time..." && exit -1

echo "Authenticating..." 
echo "$PASS" | sudo -S echo &>/dev/null 0<(echo)
[[ $? != 0 ]] && echo "Bad password" && exit -1

echo "Authentication succedded, continuing..."

export PASS

sleep 2
