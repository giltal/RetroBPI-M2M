#!/bin/bash
O=~/bpi/output
RE=$(ls $O/host/bin/*-readelf 2>/dev/null | head -1)
[ -x "$RE" ] || RE=readelf
echo "using: $RE"
echo
echo "=== pcsx_rearmed NEEDED libraries ==="
$RE -d "$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so" 2>/dev/null | grep NEEDED
echo
echo "=== a core that loads fine, for comparison ==="
$RE -d "$O/target/usr/lib/libretro/fceumm_libretro.so" 2>/dev/null | grep NEEDED
echo
echo "=== do those libs exist in the target rootfs? ==="
for lib in $($RE -d "$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so" 2>/dev/null | grep -oE 'Shared library: \[[^]]+\]' | sed 's/.*\[//;s/\]//'); do
    if find $O/target -name "$lib" | grep -q .; then
        echo "  present  $lib"
    else
        echo "  MISSING  $lib"
    fi
done
