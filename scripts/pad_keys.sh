#!/bin/sh
echo "=== tools available ==="
for t in evtest jstest hexdump od xxd; do
  printf '  %-9s %s\n' "$t" "$(command -v $t || echo missing)"
done
echo
echo "=== the pad's event node ==="
awk '/PLAYSTATION\(R\)3 Controller"/{f=1} f&&/Handlers=/{print "  "$0; f=0}' /proc/bus/input/devices
echo
echo "=== advertised KEY bitmask (does it claim BTN_THUMBL?) ==="
awk '/PLAYSTATION\(R\)3 Controller"/{f=1} f&&/B: KEY=/{print "  "$0; f=0}' /proc/bus/input/devices
echo
echo "  BTN_THUMBL = 0x13d = 317 decimal  (L3)"
echo "  BTN_THUMBR = 0x13e = 318 decimal  (R3)"
echo
echo "=== all input devices ==="
grep -E '^N: Name' /proc/bus/input/devices | sed 's/^/  /'
