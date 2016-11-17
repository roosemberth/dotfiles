#!/bin/bash
# modified from http://ficate.com/blog/2012/10/15/battery-life-in-the-land-of-tmux/

## FIXME: Deprecated sysfs for upower, more portable... See battery monitor

BATTERY='⌁'
PLUG='⚡'

ICON=${BATTERY}

# -- Uncomment a single line
# HP Pavillon DV4-4062la
# CHARGING="$([ -z "$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/status' | grep Discharging)" ] && echo true)"
# Lenovo Thinkpad P50
CHARGING=$([ $(cat /sys/class/power_supply/AC/online) -gt 0 ] && echo true)
# --

if [ "$CHARGING" = "true" ]; then
	ICON=${PLUG}
fi

# -- Battery status: Uncomment a single block
# HP Pavillon DV4-4062la
#CURRENT_CHARGE=$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/CHARGE_now')
#TOTAL_CHARGE=$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/CHARGE_full')
# - OSx
#battery_info=`ioreg -rc AppleSmartBattery`
#CURRENT_CHARGE=$(echo $battery_info | grep -o '"CurrentCapacity" = [0-9]\+' | awk '{print $3}')
#TOTAL_CHARGE=$(echo $battery_info | grep -o '"MaxCapacity" = [0-9]\+' | awk '{print $3}')
# Lenovo Thinkpad P50
CURRENT_CHARGE=$(cat /sys/class/power_supply/BAT0/energy_now)
TOTAL_CHARGE=$(cat /sys/class/power_supply/BAT0/energy_full)

if [ -x /usr/bin/bc ]; then
	CHARGE=$(echo "scale=4;((100*$CURRENT_CHARGE)/$TOTAL_CHARGE)" | bc -l)
else
	CHARGE=$((100*$CURRENT_CHARGE/$TOTAL_CHARGE))
fi

echo "${ICON} ${CHARGE}%"
