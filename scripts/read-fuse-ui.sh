#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-fuse-*/ | head -1)
echo "=== ui.c lines 80-112 (the toggle block) ==="
sed -n '80,112p' $SRC/src/compat/ui.c | cat -n | sed 's/^/  /'
