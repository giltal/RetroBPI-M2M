#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output

echo "=== rebuild kernel with the touch-release patch ==="
make O=$O linux-dirclean >/dev/null 2>&1
make O=$O linux 2>&1 | grep -E 'Applying|ERROR|Error [0-9]' | tail -8

K=$O/build/linux-6.18.8
echo
echo "=== is the fix in the built source? ==="
grep -q 'input_mt_report_slot_inactive' $K/drivers/input/touchscreen/edt-ft5x06.c \
  && echo "  OK: slot-close logic present" || { echo "  !! missing"; exit 1; }
grep -c 'seen' $K/drivers/input/touchscreen/edt-ft5x06.c

echo
echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -4

ls -l $O/images/zImage $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb
cp $O/images/zImage /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/zImage
cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo BUILD_TOUCHFIX_DONE
