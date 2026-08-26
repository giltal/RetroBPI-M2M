#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output

echo "=== rebuild the launcher from local source ==="
make O=$O retrobpi-launcher-rebuild 2>&1 | tail -12

echo
echo "=== assert the new volume code is in the binary ==="
if strings $O/target/usr/bin/retrobpi_launcher | grep -q "Headphone Playback Volume"; then
    echo "  OK: addresses 'Headphone Playback Volume' by name"
else
    echo "  !! new volume code NOT in the binary"; exit 1
fi
if strings $O/target/usr/bin/retrobpi_launcher | grep -q "numid=37"; then
    echo "  !! stale Lyra numid=37 still present"; exit 1
else
    echo "  OK: Lyra numid=37 gone"
fi
ls -l $O/target/usr/bin/retrobpi_launcher
cp $O/target/usr/bin/retrobpi_launcher /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/retrobpi_launcher

echo
echo "=== regenerate the image too ==="
make O=$O -j$(nproc) 2>&1 | tail -6
ls -l $O/images/sdcard.img
echo BUILD_LAUNCHER_DONE
