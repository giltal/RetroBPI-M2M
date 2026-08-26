#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-fuse-* | head -1)
echo "our fuse commit: $(basename $D)"
echo
echo "=== port device default at init ==="
grep -n 'retro_set_controller_port_device' "$D/src/libretro.c" | head -5
echo
echo "=== the device switch in set_controller_port_device ==="
L=$(grep -n 'void retro_set_controller_port_device' "$D/src/libretro.c" | cut -d: -f1)
echo "function at line $L"
sed -n "${L},$((L+30))p" "$D/src/libretro.c"
