#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* | head -1)
echo "=== compat/ui.c: the keyboard overlay toggle ==="
sed -n '1,60p' "$D/src/compat/ui.c"
