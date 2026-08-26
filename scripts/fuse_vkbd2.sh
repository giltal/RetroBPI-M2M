#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* | head -1)
echo "=== fuse libretro dir ==="
ls "$D/libretro/" 2>/dev/null | head
echo
echo "=== anything keyboard-overlay-ish in the whole core ==="
grep -rln 'keyboard_overlay\|KEYBOARD_OVERLAY\|vkbd\|virtual keyboard\|Virtual Keyboard' "$D" --include=*.c --include=*.h 2>/dev/null | head -6
echo
echo "=== how does fuse expose a keyboard toggle? ==="
grep -rn 'RETRO_DEVICE_ID_JOYPAD_[A-Z0-9]*.*[Kk]eyboard\|[Kk]eyboard.*RETRO_DEVICE_ID_JOYPAD' "$D" --include=*.c 2>/dev/null | head -8
