#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== core-mapper.c 310-330 ==="
sed -n '310,330p' "$D/libretro/core-mapper.c"
echo
echo "=== core-mapper.c 345-370 ==="
sed -n '345,370p' "$D/libretro/core-mapper.c"
