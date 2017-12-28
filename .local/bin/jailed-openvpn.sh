#!/usr/bin/env bash
# Usage: JAIL="ovpn-tb-usa"; sudo openvpn --config "TunnelBear United States.ovpn" --auth-user-pass =(pass show web/tunnelbear.com/1) --route-noexec --ifconfig-noexec --route-up "$(which jailed-openvpn.sh) ${JAIL}" --up "$(which jailed-openvpn.sh) ${JAIL}" --script-security 2

JAIL_NAME=${1:-OpenVPN--unnamed-jail}

case $script_type in
    up)
        ip netns add $JAIL_NAME
        ip netns exec $JAIL_NAME ip link set dev lo up
        ip netns exec $JAIL_NAME ip addr add 127.0.0.1/8 dev lo
        ip link set dev "$dev" up netns $JAIL_NAME mtu "$link_mtu"
        ip netns exec $JAIL_NAME ip addr add dev "$dev" "${ifconfig_local}"/"${ifconfig_netmask:-30}"
        ip netns exec $JAIL_NAME ip -6 addr add dev "$dev" "${ifconfig_ipv6_local}"/"${ifconfig_ipv6_netbits:-64}" 
        ;;
    route-up)
        ip netns exec $JAIL_NAME ip route add default via "$route_vpn_gateway"
        ;;
    down)
        ip netns delete $JAIL_NAME
        ;;
esac
