#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== core-mapper.c 590-625 (the poll that fills mbt) ==="
sed -n '590,625p' "$D/libretro/core-mapper.c"
