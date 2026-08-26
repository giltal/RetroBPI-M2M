#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== Atari 800 (joystick device) input descriptors, port 0 ==="
sed -n '70,95p' "$D/libretro/libretro-core.c"
