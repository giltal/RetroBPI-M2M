#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== dirclean fuse: force both patches to re-apply ==="
make O=~/bpi/output libretro-fuse-dirclean 2>&1 | tail -2
make O=~/bpi/output libretro-fuse 2>&1 | grep -iE 'Applying|patching file|error' | head -8
D=$(ls -d ~/bpi/output/build/libretro-fuse-*/)
echo "=== both fixes present in freshly patched source ==="
echo "  L1 overlay toggle : $(grep -c 'L1 also toggles the keyboard overlay' $D/src/compat/ui.c)"
echo "  Kempston default  : $(grep -c 'port_device( 0, RETRO_DEVICE_KEMPSTON_JOYSTICK )' $D/src/libretro.c)"
echo "  JOYPAD remap      : $(grep -c 'if (device == RETRO_DEVICE_JOYPAD)' $D/src/libretro.c)"
echo "  core built        : $(ls -la --time-style=+%H:%M ~/bpi/output/target/usr/lib/libretro/fuse_libretro.so | awk '{print $6,$7}')"
