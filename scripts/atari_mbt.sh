#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== where mbt is filled ==="
grep -rn 'mbt\[' "$D/libretro/"*.c 2>/dev/null | grep -vE 'return|if *\(mbt' | head -12
echo
echo "=== the polling loop that fills it ==="
grep -rn -B4 -A12 'mbt\[i\]\[j\] *=' "$D/libretro/"*.c 2>/dev/null | head -30
