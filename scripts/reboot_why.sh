#!/bin/sh
echo "=== uptime ==="; cut -d. -f1 /proc/uptime
echo
echo "=== was it a clean shutdown or a reset? ==="
grep -iE 'reboot|shutdown|power|reset|panic|oops|halt' /tmp/messages 2>/dev/null | head -10
echo
echo "=== kernel boot reason / watchdog ==="
dmesg 2>/dev/null | grep -iE 'reset|watchdog|brown|undervolt|panic' | head -8
echo
echo "=== power state now ==="
echo "  AC online : $(cat /sys/class/power_supply/axp22x-ac/online 2>/dev/null)"
echo "  USB online: $(cat /sys/class/power_supply/axp20x-usb/online 2>/dev/null)"
echo "  governor  : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "  cpu0 freq : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)"
echo
echo "=== volume after reboot (did volume=100 persist?) ==="
grep -h '^volume=' /opt/roms/_system/state.txt 2>/dev/null
echo "  mixer: $(amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep -m1 ': values' | cut -d= -f2)"
echo
echo "=== evtest processes ==="
ps w | grep '[e]vtest'
