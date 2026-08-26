#!/bin/bash
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output
P=$EXT/package/retroarch/libretro-gpsp

echo "=== regenerate .config ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -2
grep -E '^BR2_PACKAGE_LIBRETRO_GPSP' $O/.config || { echo "!! GPSP not selected"; exit 1; }

echo
echo "=== build gpsp (dirclean first: old commit's tree must go) ==="
make O=$O libretro-gpsp-dirclean >/dev/null 2>&1
rm -f $P/libretro-gpsp.hash
if make O=$O libretro-gpsp > ~/bpi/corelogs/gpsp.log 2>&1; then
    echo "  BUILD OK"
else
    echo "  BUILD FAILED"
    grep -iE 'error|changed section attributes|Error [0-9]+$' ~/bpi/corelogs/gpsp.log | head -12
    exit 1
fi

echo
echo "=== record the real hash for the new tarball ==="
TARBALL=$(ls ~/bpi/dl/libretro-gpsp/*.tar.gz 2>/dev/null | head -1)
if [ -n "$TARBALL" ]; then
    H=$(sha256sum "$TARBALL" | cut -d' ' -f1)
    printf '# Locally calculated\nsha256  %s  %s\n' "$H" "$(basename $TARBALL)" > $P/libretro-gpsp.hash
    cat $P/libretro-gpsp.hash
else
    echo "  (tarball not found under ~/bpi/dl/libretro-gpsp/)"
    ls ~/bpi/dl | head
fi

echo
echo "=== did the ARM dynarec actually get compiled in? ==="
SO=$O/target/usr/lib/libretro/gpsp_libretro.so
ls -l $SO
echo "  --- dynarec symbols/strings ---"
strings $SO | grep -iE 'dynarec|jit|translate_block|rom_translation_cache' | head -8
echo "  --- if this is an interpreter-only build, the above is empty ---"
echo BUILD_GPSP_DONE
