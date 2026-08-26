#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output
make O=$O -j$(nproc) 2>&1 | tail -6
echo
echo "=== verify the shipped ALSA baseline inside the image ==="
rm -rf /tmp/ic && mkdir -p /tmp/ic
debugfs -R "dump var/lib/alsa/asound.state /tmp/ic/asound.state" $O/images/rootfs.ext4 2>/dev/null
debugfs -R "dump etc/init.d/S35alsa /tmp/ic/S35alsa" $O/images/rootfs.ext4 2>/dev/null
echo "--- Headphone ---"
grep -A1 "name 'Headphone Playback Volume'" /tmp/ic/asound.state | head -2
echo "--- AIF1 DA0 ---"
grep -A2 "name 'AIF1 DA0 Playback Volume'" /tmp/ic/asound.state | head -3
echo "--- S35alsa fallback sets analog to max? ---"
grep -c "Headphone Playback Volume' 63" /tmp/ic/S35alsa
echo
echo "=== launcher binary in the image uses the control by name? ==="
rm -f /tmp/ic/launcher
debugfs -R "dump usr/bin/retrobpi_launcher /tmp/ic/launcher" $O/images/rootfs.ext4 2>/dev/null
strings /tmp/ic/launcher | grep -c "Headphone Playback Volume"
strings /tmp/ic/launcher | grep -c "numid=37" || true
echo "  (first count must be >=1, second must be 0)"
ls -l $O/images/sdcard.img
cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo REBUILD_DONE
