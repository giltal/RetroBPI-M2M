#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== kernel: regenerate patches (touch inversions removed) ==="
make O=$O linux-dirclean linux-extract 2>&1 | tail -1
bash $EXT/../scripts/stage_kernel_patches.sh 2>&1 | grep -E 'ERROR' || true
echo "  touchscreen-inverted in patch 0002: $(grep -c 'touchscreen-inverted' $EXT/board/bpi-m2m/patches/linux/0002-arm-dts-bananapi-m2m-panels.patch)  (comment text only)"
make O=$O linux-dirclean 2>&1 | tail -1

echo
echo "=== retroarch: rebuild with the display-rotation patch ==="
make O=$O retroarch-dirclean >/dev/null 2>&1
if make O=$O retroarch > ~/bpi/corelogs/ra.log 2>&1; then echo "  retroarch OK"; else
  echo "  retroarch FAILED"; grep -iE 'error|Reversed|malformed' ~/bpi/corelogs/ra.log | head -10; exit 1; fi
echo "  patch 0007 applied: $(grep -c '0007-gl2-fold-display-rotation' ~/bpi/corelogs/ra.log)"
echo "  define reached the compiler: $(grep -c 'DRETROBPI_DISPLAY_ROTATION=180' ~/bpi/corelogs/ra.log)"
RSRC=$(ls -d $O/build/retroarch-*/ | head -1)
grep -q 'RETROBPI_DISPLAY_ROTATION' $RSRC/gfx/drivers/gl2.c && echo "  OK: patch present in source" || { echo "  !! patch missing"; exit 1; }

echo
echo "=== atari800: rebuild without the now-redundant L1 patch ==="
make O=$O libretro-atari800-dirclean >/dev/null 2>&1
make O=$O libretro-atari800 > ~/bpi/corelogs/a800.log 2>&1 && echo "  atari800 OK" || { echo "  FAILED"; exit 1; }
ASRC=$(ls -d $O/build/libretro-atari800-*/ | head -1)
grep -q 'l1_prev' $ASRC/libretro/core-mapper.c && echo "  !! stale patch still applied" || echo "  OK: back to upstream (L3 toggles the keyboard)"

echo
echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -4

echo
echo "=== VERIFY IN IMAGE ==="
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || command -v dtc)
echo -n "  DTB touch inversions (want 0): "
$DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'touchscreen-inverted' || true
echo -n "  DTB rotation (want 1): "
$DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'rotation'
IMG=$O/images/rootfs.ext4
rm -rf /tmp/fx && mkdir -p /tmp/fx
debugfs -R "dump root/.config/retroarch/retroarch.cfg /tmp/fx/ra.cfg" $IMG 2>/dev/null
echo "  retroarch.cfg: $(grep -E '^video_rotation' /tmp/fx/ra.cfg)"
cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo BUILD_FIXES_DONE
