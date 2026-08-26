#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-fuse-*/ 2>/dev/null | head -1)
echo "source: $SRC"
[ -n "$SRC" ] || { echo "not extracted; run: make O=~/bpi/output libretro-fuse-extract"; exit 1; }
echo
echo "=== ui.c: keyboard overlay toggle ==="
grep -n -B6 -A18 'RETRO_DEVICE_ID_JOYPAD_SELECT' $SRC/src/compat/ui.c | head -45
echo
echo "=== libretro.c: default port device ==="
grep -n 'retro_set_controller_port_device' $SRC/src/libretro.c | head -6
echo
echo "=== KEMPSTON device defines ==="
grep -rn 'KEMPSTON_JOYSTICK\|CURSOR_JOYSTICK' $SRC/src/*.h $SRC/src/libretro.c 2>/dev/null | head -8
