#!/bin/bash
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output
P=$EXT/package/retroarch/libretro-atari800

echo "=== regenerate .config ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -2
grep -E '^BR2_PACKAGE_LIBRETRO_ATARI800' $O/.config || { echo "!! not selected"; exit 1; }

echo
echo "=== build (no hash file yet; recorded after fetch) ==="
rm -f $P/libretro-atari800.hash
make O=$O libretro-atari800-dirclean >/dev/null 2>&1
if make O=$O libretro-atari800 > ~/bpi/corelogs/atari800.log 2>&1; then
    echo "  BUILD OK"
else
    echo "  BUILD FAILED"
    grep -iE 'error:|Error [0-9]+$|No such file' ~/bpi/corelogs/atari800.log | head -12
    exit 1
fi

T=$(ls ~/bpi/dl/libretro-atari800/*.tar.gz 2>/dev/null | head -1)
if [ -n "$T" ]; then
    printf '# Locally calculated\nsha256  %s  %s\n' "$(sha256sum "$T" | cut -d' ' -f1)" "$(basename $T)" > $P/libretro-atari800.hash
    cat $P/libretro-atari800.hash
fi

ls -l $O/target/usr/lib/libretro/atari800_libretro.so

echo
echo "=== the virtual-keyboard hook the Lyra patched ==="
SRC=$(ls -d $O/build/libretro-atari800-*/ | head -1)
echo "  source: $SRC"
grep -n 'SHOWKEY' $SRC/libretro/core-mapper.c | head -20
echo BUILD_ATARI800_DONE
