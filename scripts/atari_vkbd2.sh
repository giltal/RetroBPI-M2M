#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* 2>/dev/null | head -1)
echo "core src: $D"
echo "=== source layout ==="
ls "$D" | head -12
echo
echo "=== files mentioning a virtual keyboard ==="
grep -rln 'vkbd\|VKBD\|virtual_kbd\|SHOWKEY' "$D" --include=*.c --include=*.h 2>/dev/null | head -8
echo
echo "=== the toggle binding ==="
grep -rn 'L3\|JOYPAD_L3\|num_keyboard\|show_keyboard\|KEYBOARD_TOGGLE' "$D" --include=*.c 2>/dev/null | head -15
