#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== rebuild fuse with the overlay patch ==="
make O=$O libretro-fuse-dirclean >/dev/null 2>&1
if make O=$O libretro-fuse > ~/bpi/corelogs/fusep.log 2>&1; then echo "  fuse OK"; else
    echo "  fuse FAILED"; grep -iE 'error|Reversed|malformed' ~/bpi/corelogs/fusep.log | head -8; exit 1; fi
SRC=$(ls -d $O/build/libretro-fuse-*/ | head -1)
grep -q 'RETRO_DEVICE_ID_JOYPAD_L)' $SRC/src/compat/ui.c && echo "  OK: L1 toggle in built source" || { echo "  !! patch missing"; exit 1; }

echo
echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -5

echo
echo "=== cores in image ==="
IMG=$O/images/rootfs.ext4
debugfs -R "ls -l usr/lib/libretro" $IMG 2>/dev/null | awk '{print $NF}' | grep '_libretro.so' | sort | tr '\n' ' '
echo
echo "  count: $(debugfs -R 'ls -l usr/lib/libretro' $IMG 2>/dev/null | grep -c '_libretro.so')"

echo
echo "=== patched cores carry their changes? ==="
rm -rf /tmp/f2 && mkdir -p /tmp/f2
for c in atari800 fuse; do
  debugfs -R "dump usr/lib/libretro/${c}_libretro.so /tmp/f2/$c.so" $IMG 2>/dev/null
  printf "  %-10s %s bytes\n" "$c" "$(stat -c%s /tmp/f2/$c.so 2>/dev/null)"
done
cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo BUILD_FINAL2_DONE
