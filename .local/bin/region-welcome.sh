#!/usr/bin/env bash

printf "Querying network data...\r"

# shellcheck disable=SC2034
read -sr GEO_status GEO_country GEO_countryCode GEO_region GEO_regionName \
    GEO_city GEO_zip GEO_lat GEO_lon GEO_timezone GEO_isp GEO_org \
    GEO_as GEO_query <<<"$(curl -s 'ip-api.com/line' | tr " " "_" | tr '\n' " ")"

[ "$GEO_status" = "success" ] || exit 10

query_iface="$(ip -br r get "$(getent ahostsv4 orbstheorem.ch | awk '{print $1; exit}')" | grep -oP 'dev \K\S+')"

#typeset -gxrm "GEO_*"
localTime=$(eval "TZ='$GEO_timezone' date")

echo "Welcome to ${GEO_city}, ${GEO_regionName} - ${GEO_country}!"
echo "IP ${GEO_query} via ${query_iface} provided by ${GEO_as}"
echo "Local time: $localTime"
default-routes.sh | while read -r if gw; do
if_addr="$(ip -4 -br addr show dev "$if" | awk '{print $3}')"
echo "$if $if_addr $gw"
done
