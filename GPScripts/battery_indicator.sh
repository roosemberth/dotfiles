#!/bin/bash
# modified from http://ficate.com/blog/2012/10/15/battery-life-in-the-land-of-tmux/

BATTERY='🔋'
PLUG='🔌'

ICON=${BATTERY}

if [ -z "$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/status' | grep Discharging)" ]; then
	ICON=${PLUG}
fi


if [[ `uname` == 'Linux' ]]; then
  current_charge=$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/charge_now')
  total_charge=$(cat '/sys/bus/acpi/drivers/battery/PNP0C0A:00/power_supply/BAT0/charge_full')
else
  battery_info=`ioreg -rc AppleSmartBattery`
  current_charge=$(echo $battery_info | grep -o '"CurrentCapacity" = [0-9]\+' | awk '{print $3}')
  total_charge=$(echo $battery_info | grep -o '"MaxCapacity" = [0-9]\+' | awk '{print $3}')
fi

charge=$(echo "((100*$current_charge)/$total_charge)" | bc -l | cut -d '.' -f 1)
echo "${ICON} ${charge}%"
