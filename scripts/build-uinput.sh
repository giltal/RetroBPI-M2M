#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== reconfiguring kernel with the uinput fragment ==="
make O=~/bpi/output linux-reconfigure 2>&1 | tail -20
echo
echo "=== assert uinput landed in the generated .config ==="
grep -E '^CONFIG_INPUT_UINPUT' ~/bpi/output/build/linux-6.18.8/.config || { echo "!! uinput MISSING"; exit 1; }
echo "=== assert nothing else regressed ==="
for s in CONFIG_BT=y CONFIG_UHID=y CONFIG_DRM_LIMA=y CONFIG_SND_SIMPLE_CARD=y; do
    grep -qE "^$s" ~/bpi/output/build/linux-6.18.8/.config && echo "  OK   $s" || echo "  LOST $s"
done
echo
echo "=== cross-compile inject-input ==="
CC=$(ls ~/bpi/output/host/bin/*-linux-gcc 2>/dev/null | head -1)
echo "  CC=$CC"
$CC -O2 -Wall -o ~/bpi/output/target/usr/bin/inject-input \
    /mnt/c/BananaPi_Projects/RetroBPI_M2M/tools/inject-input.c
file ~/bpi/output/target/usr/bin/inject-input
cp ~/bpi/output/target/usr/bin/inject-input ~/bpi/inject-input
echo
echo "=== rebuild images ==="
make O=~/bpi/output -j$(nproc) 2>&1 | tail -12
ls -l ~/bpi/output/images/zImage ~/bpi/output/images/sdcard.img
echo BUILD_UINPUT_DONE
