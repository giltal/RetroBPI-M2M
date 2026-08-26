#!/bin/sh
echo "=== RetroArch autoconfig profiles for the pad ==="
ls /usr/share/retroarch/autoconfig/ 2>/dev/null | head
for f in /usr/share/retroarch/autoconfig/*/*ony*3* /usr/share/retroarch/autoconfig/*ony*3*; do
  [ -f "$f" ] && { echo "--- $f ---"; grep -E 'input_.*_btn|input_device' "$f" | head -25; }
done 2>/dev/null
echo
echo "=== the pad as evdev sees it ==="
cat /proc/bus/input/devices 2>/dev/null | grep -A6 'PLAYSTATION(R)3 Controller"'
echo
echo "=== which evdev buttons does it advertise? ==="
D=$(grep -B4 'PLAYSTATION(R)3 Controller"' /proc/bus/input/devices 2>/dev/null | grep -o 'event[0-9]*' | head -1)
echo "device: $D"
