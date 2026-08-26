#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
echo "=== reconfigure kernel with the updated fragment ==="
make O=~/bpi/output linux-reconfigure 2>&1 | tail -5
echo "=== verify the option actually landed in .config ==="
grep -E 'CONFIG_FRAMEBUFFER_CONSOLE_ROTATION' ~/bpi/output/build/linux-6.18.8/.config || echo "  NOT SET - fragment did not apply"
echo "=== result ==="
ls -la --time-style=+%H:%M ~/bpi/output/images/zImage
