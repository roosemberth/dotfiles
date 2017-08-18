#!/usr/bin/env bash

netTestDomain="orbstheorem.ch"

echo -e "Querying network data...\r"

read -sr GEO_status GEO_country GEO_countryCode GEO_region GEO_regionName \
    GEO_city GEO_zip GEO_lat GEO_lon GEO_timezone GEO_isp GEO_org \
    GEO_as GEO_query <<<$(curl -s 'ip-api.com/line' | tr " " "_" | tr '\n' " ")

[ "$GEO_status" = "success" ] || exit 10

#typeset -gxrm "GEO_*"
localTime=$(eval "TZ='$GEO_timezone' date")

echo "------------------------------------------------------------"
echo "       Welcome to ${GEO_city}, ${GEO_regionName} - ${GEO_country}!"
echo "IP ${GEO_query} provided by ${GEO_as}"
echo "  Local time: $localTime"
echo "$(ip r get "$(dig +short $netTestDomain)" connected | grep -v cache | tail -n 1 | awk '{print $3" ("$7") -> "$5" -> "$1}')"
echo "------------------------------------------------------------"
