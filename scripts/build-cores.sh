#!/bin/bash
# Build each libretro core separately. Buildroot stops the whole build on the
# first failure, which tells you nothing about the other 14 -- so each core is
# built on its own and the failures are collected into a report.
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output
LOG=~/bpi/corelogs
mkdir -p $LOG

echo "=== regenerate .config ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -3

echo
echo "=== which cores survived dependency resolution? ==="
grep -E '^BR2_PACKAGE_LIBRETRO.*=y' $O/.config | sed 's/BR2_PACKAGE_LIBRETRO_//;s/=y//' | tr '\n' ' '
echo

CORES=$(grep -E '^BR2_PACKAGE_LIBRETRO.*=y' $O/.config | sed 's/BR2_PACKAGE_LIBRETRO_//;s/=y//' | tr 'A-Z_' 'a-z-')

OK=""; FAIL=""
for c in $CORES; do
    pkg="libretro-$c"
    printf "  %-22s " "$pkg"
    if make O=$O "$pkg" > "$LOG/$c.log" 2>&1; then
        echo "ok"
        OK="$OK $c"
    else
        echo "FAILED"
        FAIL="$FAIL $c"
    fi
done

echo
echo "=== RESULT ==="
echo "  built  :$OK"
echo "  failed :$FAIL"

if [ -n "$FAIL" ]; then
    echo
    echo "=== failure tails ==="
    for c in $FAIL; do
        echo "--- $c ---"
        grep -iE 'error|Error [0-9]|No such file|undefined reference|cannot find' "$LOG/$c.log" | head -8
    done
fi

echo
echo "=== cores actually installed to target ==="
ls $O/target/usr/lib/libretro/*.so 2>/dev/null | sed 's|.*/||' | tr '\n' ' '
echo
echo "  count: $(ls $O/target/usr/lib/libretro/*.so 2>/dev/null | wc -l)"
echo BUILD_CORES_DONE
