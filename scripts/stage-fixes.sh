#!/bin/bash
set -e
O=~/bpi/output
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/fix
rm -rf $P && mkdir -p $P
cp $O/images/sun8i-a33-bananapi-m2m-ws5b.dtb        $P/
cp $O/images/zImage                                  $P/
cp $O/target/usr/bin/retroarch.bin                   $P/
cp $O/target/root/.config/retroarch/retroarch.cfg    $P/
cp $O/target/usr/lib/libretro/atari800_libretro.so   $P/
echo "=== staged ==="
ls -l $P | tail -6
echo
echo "=== pre-push sanity ==="
DTC=$(ls $O/host/bin/linux-dtc 2>/dev/null || command -v dtc)
echo -n "  DTB touch inversions (want 0) : "
$DTC -I dtb -O dts $P/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'touchscreen-inverted' || echo 0
echo -n "  DTB rotation property (want 1): "
$DTC -I dtb -O dts $P/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | grep -c 'rotation'
echo -n "  retroarch.cfg video_rotation  : "
grep -E '^video_rotation' $P/retroarch.cfg
echo -n "  atari800 free of the dropped patch: "
if strings $P/atari800_libretro.so | grep -q 'l1_prev'; then echo "NO (stale)"; else echo "yes"; fi
