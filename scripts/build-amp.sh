#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output

echo "=== pristine kernel tree (required by the patch generator) ==="
make O=$O linux-dirclean linux-extract 2>&1 | tail -4

echo
echo "=== regenerate kernel patches from kernel/*.dts ==="
bash /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/stage_kernel_patches.sh 2>&1 | tail -20

echo
echo "=== the amp really is in patch 0002? ==="
grep -c 'simple-audio-amplifier' /mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/linux/0002*.patch
grep -c 'Speaker Amp INL' /mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/linux/0002*.patch

echo
echo "=== dirclean AGAIN: stage_kernel_patches.sh leaves the tree already-patched, ==="
echo "=== so Buildroot would try to re-apply its own patches and fail.            ==="
make O=$O linux-dirclean 2>&1 | tail -2

echo
echo "=== rebuild ==="
make O=$O -j$(nproc) 2>&1 | tail -10

echo
echo "=== VERIFY THE BUILT DTB ==="
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || which dtc)
echo "  using $DTC"
$DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null > /tmp/ws5b.decompiled.dts
echo "--- amplifier node ---"
grep -A6 'audio-amplifier' /tmp/ws5b.decompiled.dts | head -12
echo "--- sound card routing ---"
sed -n '/sound {/,/};/p' /tmp/ws5b.decompiled.dts | head -30
echo
echo "--- enable-gpios decodes to which bank/pin? ---"
grep -A4 'audio-amplifier' /tmp/ws5b.decompiled.dts | grep -i 'enable-gpios'
echo "  (phandle then <bank pin flags>; bank 0x07 = PH, pin 0x09 = PH9)"

ls -l $O/images/sdcard.img $O/images/zImage $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb
echo BUILD_AMP_DONE
