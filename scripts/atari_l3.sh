#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== platform.c 675-715 (the L3 handler) ==="
sed -n '675,715p' "$D/libretro/platform.c"
echo
echo "=== is this path gated by machine type? ==="
sed -n '660,678p' "$D/libretro/platform.c"
