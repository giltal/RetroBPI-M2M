#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* | head -1)
echo "=== compat/ui.c 60-130: where SELECT toggles the overlay ==="
sed -n '60,130p' "$D/src/compat/ui.c"
