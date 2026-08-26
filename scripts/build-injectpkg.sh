#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external

echo "=== regenerate .config from the defconfig ==="
make BR2_EXTERNAL=$EXT O=~/bpi/output bpi_m2m_retro_defconfig 2>&1 | tail -5

echo
echo "=== did the new option survive dependency resolution? ==="
grep -E '^BR2_PACKAGE_INJECT_INPUT' ~/bpi/output/.config || { echo "!! option dropped"; exit 1; }
echo "=== sanity: other packages still selected ==="
for s in BR2_PACKAGE_RETROARCH BR2_PACKAGE_RETROBPI_LAUNCHER BR2_PACKAGE_MESA3D_GALLIUM_DRIVER_LIMA BR2_PACKAGE_BLUEZ5_UTILS BR2_PACKAGE_ALSA_UTILS; do
    grep -qE "^$s=y" ~/bpi/output/.config && echo "  OK   $s" || echo "  LOST $s"
done

echo
echo "=== build just the package first ==="
rm -f ~/bpi/output/target/usr/bin/inject-input
make O=~/bpi/output inject-input-dirclean inject-input 2>&1 | tail -15
ls -l ~/bpi/output/target/usr/bin/inject-input
file ~/bpi/output/target/usr/bin/inject-input

echo
echo "=== full image rebuild ==="
make O=~/bpi/output -j$(nproc) 2>&1 | tail -8
ls -l ~/bpi/output/images/sdcard.img ~/bpi/output/images/zImage

echo
echo "=== assert the tool + the fixed alsa files are IN the rootfs image ==="
mkdir -p /tmp/rcheck && rm -rf /tmp/rcheck/*
cd /tmp/rcheck
7z x -y ~/bpi/output/images/rootfs.ext4 usr/bin/inject-input etc/init.d/S35alsa var/lib/alsa/asound.state >/dev/null 2>&1 || true
if [ ! -f usr/bin/inject-input ]; then
    echo "  (7z unavailable, using debugfs)"
    debugfs -R "stat usr/bin/inject-input" ~/bpi/output/images/rootfs.ext4 2>/dev/null | head -3
    debugfs -R "dump var/lib/alsa/asound.state /tmp/rcheck/asound.state" ~/bpi/output/images/rootfs.ext4 2>/dev/null
    debugfs -R "dump etc/init.d/S35alsa /tmp/rcheck/S35alsa" ~/bpi/output/images/rootfs.ext4 2>/dev/null
fi
echo "--- asound.state in the image says: ---"
grep -A2 "Headphone Playback Volume" /tmp/rcheck/asound.state 2>/dev/null | head -3
grep -A2 "Headphone Playback Switch" /tmp/rcheck/asound.state 2>/dev/null | head -3
echo "--- S35alsa has the fallback? ---"
grep -c 'headphone_audible\|apply_defaults' /tmp/rcheck/S35alsa 2>/dev/null
echo BUILD_INJECTPKG_DONE
