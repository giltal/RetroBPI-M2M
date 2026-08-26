#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== regenerate .config (picks up PANEL_ROTATION) ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -2
grep -E '^BR2_PACKAGE_RETROBPI_LAUNCHER_PANEL_ROTATION' $O/.config || { echo "!! rotation option missing"; exit 1; }

echo
echo "=== pristine kernel tree, regenerate patches from kernel/*.dts ==="
make O=$O linux-dirclean linux-extract 2>&1 | tail -2
bash $EXT/../scripts/stage_kernel_patches.sh 2>&1 | grep -E 'new:|mod:|ERROR' | head
echo "  rotation in patch 0002: $(grep -c 'rotation = <180>' $EXT/board/bpi-m2m/patches/linux/0002-arm-dts-bananapi-m2m-panels.patch)"
make O=$O linux-dirclean 2>&1 | tail -1

echo
echo "=== rebuild launcher with rotation ==="
make O=$O retrobpi-launcher-rebuild 2>&1 | grep -E 'PANEL_ROTATION|error|Error' | head -4

echo
echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -5

echo
echo "=== VERIFY ==="
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || command -v dtc)
echo "--- DTB carries the rotation property? ---"
$DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -A2 -B2 'rotation'
echo "--- touch inversions still present (unchanged, unverified)? ---"
$DTC -I dtb -O dts $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'touchscreen-inverted'

IMG=$O/images/rootfs.ext4
rm -rf /tmp/rot && mkdir -p /tmp/rot
debugfs -R "dump usr/bin/retrobpi_launcher /tmp/rot/launcher" $IMG 2>/dev/null
echo "--- launcher built with rotation? (log string) ---"
strings /tmp/rot/launcher | grep -i 'rotation' | head -3
debugfs -R "dump root/.config/retroarch/retroarch.cfg /tmp/rot/ra.cfg" $IMG 2>/dev/null
echo "--- retroarch.cfg ---"
grep -E '^video_rotation' /tmp/rot/ra.cfg

cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
cp $O/images/zImage /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/zImage
cp $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/
echo BUILD_ROTATE_DONE
