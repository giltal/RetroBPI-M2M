#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== platform.c patched? ==="
grep -c 'JOYPAD_L3\] || mbt\[i\]\[RETRO_DEVICE_ID_JOYPAD_R\]' "$D/libretro/platform.c"
echo "=== the descriptor line, shown with visible whitespace ==="
grep -n 'JOYPAD_L3, "Virtual Keyboard"' "$D/libretro/libretro-core.c" | cat -A | head -3
