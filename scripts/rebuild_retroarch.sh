#!/bin/sh
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
make O=~/bpi/output retroarch-rebuild 2>&1 | grep -iE 'error|warning: implicit|Entering|Leaving|Installing' | tail -8
echo "=== result ==="
ls -la --time-style=+%H:%M ~/bpi/output/target/usr/bin/retroarch
echo "probe present: $(strings ~/bpi/output/target/usr/bin/retroarch | grep -c 'RETROBPI_AUDIO_PROBE\|headroom_permille')"
