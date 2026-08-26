#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-atari800-*/ | head -1)
F=$SRC/libretro/core-mapper.c
echo "=== around the commented-out toggle (line 645) ==="
sed -n '600,680p' $F
echo
echo "=== joypad_bits / RETRO_DEVICE_ID_JOYPAD_L usage ==="
grep -n 'joypad_bits\|RETRO_DEVICE_ID_JOYPAD_L\b' $F | head -10
echo
echo "=== Screen_SetFullUpdate available? ==="
grep -n 'Screen_SetFullUpdate' $F | head -5
