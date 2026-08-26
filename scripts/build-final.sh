#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== regenerate .config ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -3

echo
echo "=== option sanity ==="
for s in BR2_PACKAGE_RETROBPI_TOOLS BR2_PACKAGE_RETROARCH BR2_PACKAGE_RETROBPI_LAUNCHER \
         BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_LIMA BR2_PACKAGE_BLUEZ5_UTILS BR2_PACKAGE_ALSA_UTILS; do
    grep -qE "^$s=y" $O/.config && echo "  OK   $s" || echo "  LOST $s"
done
grep -qE '^BR2_PACKAGE_ANDROID_TOOLS' $O/.config && echo "  !! android-tools still selected" || echo "  OK   android-tools gone"
grep -E '^BR2_ROOTFS_POST_BUILD_SCRIPT' $O/.config

echo
echo "=== build ==="
make O=$O -j$(nproc) 2>&1 | tail -14

echo
echo "=== VERIFY INSIDE THE ROOTFS IMAGE ==="
IMG=$O/images/rootfs.ext4
chk() { debugfs -R "stat $1" $IMG 2>/dev/null | grep -q '^Inode:' && echo "  present  $1" || echo "  ABSENT   $1"; }
chk etc/init.d/S12launcher
chk etc/init.d/S01seedrng
chk etc/init.d/S40network
chk etc/init.d/S35alsa
chk etc/init.d/rcS
chk usr/bin/inject-input
chk var/lib/alsa/asound.state
echo "--- these MUST be absent ---"
chk etc/init.d/S99launcher
chk etc/init.d/S50adbd
chk usr/bin/adbd
chk usr/bin/seed-credit

echo
echo "=== contents check ==="
rm -rf /tmp/vchk && mkdir -p /tmp/vchk
for f in root/.config/retroarch/retroarch.cfg etc/init.d/S01seedrng etc/init.d/S40network var/lib/alsa/asound.state; do
    debugfs -R "dump $f /tmp/vchk/$(basename $f)" $IMG 2>/dev/null
done
echo "--- retroarch.cfg ---"
grep -E '^(video_vsync|audio_latency|video_driver|audio_driver)' /tmp/vchk/retroarch.cfg
echo "--- asound.state headphone ---"
grep -A1 "Headphone Playback Volume" /tmp/vchk/asound.state | head -2
echo "--- seedrng backgrounded? ---"
grep -c '&$' /tmp/vchk/S01seedrng
echo "--- network backgrounded? ---"
grep -c 'ifup -a' /tmp/vchk/S40network

echo
ls -l $O/images/sdcard.img $O/images/zImage
echo BUILD_FINAL_DONE
