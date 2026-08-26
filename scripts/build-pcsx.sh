#!/bin/bash
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output
P=$EXT/package/retroarch/libretro-pcsx

echo "=== regenerate .config ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -2
grep -E '^BR2_PACKAGE_LIBRETRO_PCSX' $O/.config || { echo "!! PCSX not selected"; exit 1; }

echo
echo "=== build ==="
rm -f $P/libretro-pcsx.hash
make O=$O libretro-pcsx-dirclean >/dev/null 2>&1
if make O=$O libretro-pcsx > ~/bpi/corelogs/pcsx.log 2>&1; then
    echo "  BUILD OK"
else
    echo "  BUILD FAILED"
    grep -iE 'error:|Error [0-9]+$|404|No hash|multiple definition' ~/bpi/corelogs/pcsx.log | head -12
    exit 1
fi

T=$(ls ~/bpi/dl/libretro-pcsx/*.tar.gz 2>/dev/null | head -1)
if [ -n "$T" ]; then
    printf '# Locally calculated\nsha256  %s  %s\n' "$(sha256sum "$T" | cut -d' ' -f1)" "$(basename $T)" > $P/libretro-pcsx.hash
    cat $P/libretro-pcsx.hash
fi

SO=$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so
ls -l $SO
echo
echo "=== is the ARM dynarec compiled in? (the whole point of this core) ==="
strings $SO | grep -iE 'new_dynarec|dynarec|recompil' | head -6
echo
echo "=== NEON GPU plugin present? ==="
strings $SO | grep -iE 'gpu_neon|neon' | head -5
echo
echo "=== core options it offers ==="
strings $SO | grep -E '^pcsx_rearmed_(drc|spu_thread|frameskip_type|gpu_thread_rendering|dithering)$' | head
echo BUILD_PCSX_DONE
