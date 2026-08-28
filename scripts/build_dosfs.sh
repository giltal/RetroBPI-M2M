#!/bin/bash
set -e
cd ~/bpi/buildroot
BR2_DL_DIR=~/bpi/dl make BR2_EXTERNAL=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external O=~/bpi/output bpi_m2m_retro_defconfig >/dev/null 2>&1
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output dosfstools-dirclean >/dev/null 2>&1 || true
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output dosfstools 2>&1 | tail -4
T=/home/giltal/bpi/output/target
echo "=== installed ==="
find "$T" -name 'fsck.fat' -o -name 'fsck.vfat' -o -name 'dosfsck' 2>/dev/null | sed 's/^/  /'
F=$(find "$T" -name 'fsck.fat' | head -1)
[ -n "$F" ] && cp "$F" /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/fsck.fat && echo "  staged fsck.fat" || { echo "  FAIL: fsck.fat not built"; exit 1; }
