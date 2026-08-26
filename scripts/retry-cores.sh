#!/bin/bash
# Rebuild specific cores from scratch (dirclean first, so the compat CFLAGS
# actually take effect -- a plain rebuild would reuse the stale .stamp_built).
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output
LOG=~/bpi/corelogs
mkdir -p $LOG

OK=""; FAIL=""
for c in "$@"; do
    pkg="libretro-$c"
    printf "  %-22s " "$pkg"
    if make O=$O "$pkg-dirclean" >/dev/null 2>&1 && make O=$O "$pkg" > "$LOG/$c.log" 2>&1; then
        echo "ok"
        OK="$OK $c"
    else
        echo "FAILED"
        FAIL="$FAIL $c"
    fi
done

echo
echo "  built  :$OK"
echo "  failed :$FAIL"

if [ -n "$FAIL" ]; then
    echo
    for c in $FAIL; do
        echo "--- $c ---"
        grep -inE 'error:|multiple definition|undefined reference|Error [0-9]+$' "$LOG/$c.log" | head -6
    done
fi

echo
echo "=== cores installed to target ==="
ls $O/target/usr/lib/libretro/*.so 2>/dev/null | sed 's|.*/||' | tr '\n' ' '
echo
echo "  count: $(ls $O/target/usr/lib/libretro/*.so 2>/dev/null | wc -l)"
echo RETRY_DONE
