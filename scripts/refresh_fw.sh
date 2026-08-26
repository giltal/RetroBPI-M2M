#!/bin/sh
set -e
IMG=/home/giltal/bpi/output/images/sdcard.img
CORE=/home/giltal/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
FW=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img

# A missing file must be an error, not a zero. This check exists because an
# earlier version of it pointed at the wrong filename and reported "0" markers
# for a file that did not exist.
[ -f "$CORE" ] || { echo "FATAL: core not found at $CORE" >&2; exit 1; }

echo "core md5        : $(md5sum "$CORE" | cut -d' ' -f1)"
N=$(strings "$CORE" | grep -cE 'astick\.log|glitch\.log|ra_audio\.log|speed_permille' || true)
echo "instrumentation : $N (must be 0)"
[ "$N" = "0" ] || { echo "FATAL: instrumented core" >&2; exit 1; }

echo "img md5 : $(md5sum "$IMG" | cut -d' ' -f1)"
echo "fw  md5 : $(md5sum "$FW"  | cut -d' ' -f1)"
