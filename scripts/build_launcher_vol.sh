#!/bin/bash
set -e
cd ~/bpi/buildroot
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output retrobpi-tools-dirclean >/dev/null 2>&1 || true
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output retrobpi-tools 2>&1 | grep -iE 'error|warning: .*volumed|Installing' | head -10
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output retrobpi-launcher-dirclean >/dev/null 2>&1 || true
BR2_DL_DIR=~/bpi/dl make O=~/bpi/output retrobpi-launcher 2>&1 | grep -iE '^.*error|Installing' | head -10
T=/home/giltal/bpi/output/target/usr/bin
echo "=== built ==="
for p in volumed retrobpi_launcher; do
  [ -x "$T/$p" ] && echo "  OK $p ($(stat -c %s "$T/$p") bytes)" || { echo "  FAIL $p"; exit 1; }
done
echo "=== launcher persists the mixer value now? ==="
strings "$T/retrobpi_launcher" | grep -c "Headphone Playback Volume' 2>/dev/null" | sed 's/^/  cget query present: /'
cp "$T/volumed" /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/volumed
cp "$T/retrobpi_launcher" /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/retrobpi_launcher
