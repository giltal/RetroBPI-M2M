#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== dirclean atari800: forces the patch to re-apply from scratch ==="
make O=~/bpi/output libretro-atari800-dirclean 2>&1 | tail -2
make O=~/bpi/output libretro-atari800 2>&1 | grep -iE 'Applying|patching|error' | head -8
D=$(ls -d ~/bpi/output/build/libretro-atari800-*/)
echo "=== fixes present in freshly patched source ==="
echo "  R accepted for vkbd : $(grep -c 'JOYPAD_L3\] || mbt\[i\]\[RETRO_DEVICE_ID_JOYPAD_R\]' $D/libretro/platform.c)"
echo "  descriptor added    : $(grep -c 'Virtual Keyboard (alt)' $D/libretro/libretro-core.c)"
echo "  core built          : $(ls -la --time-style=+%H:%M ~/bpi/output/target/usr/lib/libretro/atari800_libretro.so | awk '{print $6, $7}')"
