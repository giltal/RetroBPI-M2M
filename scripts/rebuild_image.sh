#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== force launcher rebuild ==="
make O=~/bpi/output retrobpi-launcher-rebuild 2>&1 | tail -20
echo "=== full make (reassembles rootfs + sdcard.img) ==="
make O=~/bpi/output -j$(nproc) 2>&1 | tail -40
echo "=== result ==="
ls -la --time-style=+%Y-%m-%d_%H:%M ~/bpi/output/images/sdcard.img
