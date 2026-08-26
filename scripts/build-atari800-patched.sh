#!/bin/bash
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output

echo "=== rebuild atari800 with the patch applied ==="
make O=$O libretro-atari800-dirclean >/dev/null 2>&1
if make O=$O libretro-atari800 > ~/bpi/corelogs/atari800p.log 2>&1; then
    echo "  BUILD OK"
else
    echo "  BUILD FAILED"
    grep -iE 'error|patch|Reversed|malformed' ~/bpi/corelogs/atari800p.log | head -12
    exit 1
fi

echo
echo "=== did the patch actually apply? ==="
grep -iE 'Applying.*atari800|patch' ~/bpi/corelogs/atari800p.log | head -5
SRC=$(ls -d $O/build/libretro-atari800-*/ | head -1)
if grep -q 'l1_prev' $SRC/libretro/core-mapper.c; then
    echo "  OK: L1 toggle present in the built source"
else
    echo "  !! patch did NOT apply"; exit 1
fi

echo
echo "=== binary ==="
ls -l $O/target/usr/lib/libretro/atari800_libretro.so
echo BUILD_ATARI800P_DONE
