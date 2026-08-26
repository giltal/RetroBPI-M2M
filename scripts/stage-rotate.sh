#!/bin/bash
set -e
O=~/bpi/output
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/rot
rm -rf $P && mkdir -p $P
cp $O/images/zImage                                  $P/
cp $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb         $P/
cp $O/target/usr/bin/retrobpi_launcher               $P/
cp $O/target/root/.config/retroarch/retroarch.cfg    $P/
echo "=== staged for push ==="
ls -l $P | tail -5
echo
echo "=== sanity before pushing ==="
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || command -v dtc)
echo -n "  DTB rotation property : "
$DTC -I dtb -O dts $P/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'rotation'
echo -n "  DTB touch inversions  : "
$DTC -I dtb -O dts $P/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'touchscreen-inverted'
echo -n "  launcher rotation log : "
strings $P/retrobpi_launcher | grep -c 'rotation %d'
echo -n "  retroarch video_rotation: "
grep -c '^video_rotation = "2"' $P/retroarch.cfg
