#!/usr/bin/env bash

ip -j route | jq -r 'map(select(.dst == "default")|(.dev)+" "+(.gateway))|.[]'
