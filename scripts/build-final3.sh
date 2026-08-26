#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -4

IMG=$O/images/rootfs.ext4
rm -rf /tmp/fin3 && mkdir -p /tmp/fin3

echo
echo "=== VERIFY IN IMAGE ==="
echo "--- kernel carries the touch-release fix ---"
grep -q 'input_mt_report_slot_inactive' $O/build/linux-6.18.8/drivers/input/touchscreen/edt-ft5x06.c \
  && echo "  OK  slot-close logic in the built kernel source" || echo "  !!  missing"

echo "--- launcher: no touch rotation, no debug logging ---"
debugfs -R "dump usr/bin/retrobpi_launcher /tmp/fin3/launcher" $IMG 2>/dev/null
if strings /tmp/fin3/launcher | grep -q TOUCHDBG; then echo "  !!  debug logging still shipped"; else echo "  OK  debug logging stripped"; fi
strings /tmp/fin3/launcher | grep -q 'rotation %d' && echo "  OK  display rotation still present" || echo "  !!  display rotation lost"

echo "--- DTB: rotation kept, no touch inversions ---"
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || command -v dtc)
echo -n "  rotation property : "; $DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'rotation'
echo -n "  touch inversions  : "; ($DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'touchscreen-inverted') || echo 0

echo "--- retroarch config ---"
debugfs -R "dump root/.config/retroarch/retroarch.cfg /tmp/fin3/ra.cfg" $IMG 2>/dev/null
grep -E '^(video_rotation|input_volume_up_btn)' /tmp/fin3/ra.cfg
echo "--- per-core overrides ---"
debugfs -R "ls root/.config/retroarch/config" $IMG 2>/dev/null | tr -s ' ' '\n' | grep -viE '^\.|^[0-9]+$|^$' | tr '\n' ' '
echo
echo "--- cores ---"
echo -n "  count: "; debugfs -R 'ls -l usr/lib/libretro' $IMG 2>/dev/null | grep -c '_libretro.so'

cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
cp $O/images/zImage     /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/zImage
ls -l $O/images/sdcard.img
echo BUILD_FINAL3_DONE
