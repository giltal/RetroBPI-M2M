#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* | head -1)
L=$(grep -n 'void retro_set_controller_port_device' "$D/src/libretro.c" | tail -1 | cut -d: -f1)
echo "function at line $L"
sed -n "${L},$((L+5))p" "$D/src/libretro.c" | cat -A
