#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-atari800-*/ | head -1)
echo "=== what does atari800_vkbd_enabled gate? ==="
grep -rn -B4 -A12 'atari800_vkbd_enabled' $SRC/libretro/*.c $SRC/libretro/*.h 2>/dev/null | head -40
