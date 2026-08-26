#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== device types offered ==="
grep -rn 'RETRO_DEVICE_ATARI_KEYBOARD\|RETRO_DEVICE_ATARI_JOYSTICK\|atari_devices\[0\] *=' "$D/libretro/libretro-core.c" 2>/dev/null | head -12
echo
echo "=== default device set at init ==="
grep -rn -B3 -A6 'atari_devices\[.*\] *= ' "$D/libretro/libretro-core.c" 2>/dev/null | head -25
