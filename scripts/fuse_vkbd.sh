#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* 2>/dev/null | head -1)
echo "fuse src: $D"
echo "=== what toggles the fuse virtual keyboard? ==="
grep -rn 'JOYPAD_L3\|JOYPAD_L2\|JOYPAD_L\b\|SHOW_KEYBOARD\|show_keyboard\|vkbd' "$D/libretro/"*.c 2>/dev/null | grep -iE 'keyboard|vkbd' | head -12
echo
echo "=== fuse input descriptors mentioning keyboard ==="
grep -rn 'Keyboard' "$D/libretro/libretro.c" 2>/dev/null | head -8
