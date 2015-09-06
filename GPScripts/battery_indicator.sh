#!/bin/bash
# modified from http://ficate.com/blog/2012/10/15/battery-life-in-the-land-of-tmux/

BATTERY='🔋'
PLUG='🔌'

ICON=${BATTERY}

if [ -z "$(cat /proc/acpi/ac_adapter/AC/state | grep off)" ]; then
	ICON=${PLUG}
fi


if [[ `uname` == 'Linux' ]]; then
  current_charge=$(cat /proc/acpi/battery/BAT0/state | grep 'remaining capacity' | awk '{print $3}')
  total_charge=$(cat /proc/acpi/battery/BAT0/info | grep 'last full capacity' | awk '{print $4}')
else
  battery_info=`ioreg -rc AppleSmartBattery`
  current_charge=$(echo $battery_info | grep -o '"CurrentCapacity" = [0-9]\+' | awk '{print $3}')
  total_charge=$(echo $battery_info | grep -o '"MaxCapacity" = [0-9]\+' | awk '{print $3}')
fi

charge=$(echo "((100*$current_charge)/$total_charge)" | bc -l | cut -d '.' -f 1)
echo "${ICON} ${charge}%"
