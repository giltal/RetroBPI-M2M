#!/bin/bash
F=$(find /home/giltal/bpi/output/build/busybox-* -name 'seedrng.c' 2>/dev/null | head -1)
echo "file: $F"
echo "=== order of operations in main() ==="
sed -n '/int seedrng_main/,/^}/p' "$F" | grep -nE 'seed_from_file|seed_to_file|getrandom|read_new|credit|CREDIT|fsync|sync|lock|open|ioctl|RNDADD' | head -40
echo
echo "=== the credit path ==="
grep -n 'RNDADDENTROPY' -B8 -A8 "$F" | head -40
echo
echo "=== does it block on getrandom? ==="
grep -n 'getrandom' -B4 -A6 "$F" | head -40
