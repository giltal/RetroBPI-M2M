#!/bin/sh
set -e
SRC=~/bpi/output/images/sdcard.img
DST=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo "src: $(ls -la --time-style=+%Y-%m-%d_%H:%M $SRC)"
cp "$SRC" "$DST"
echo "copied:"
ls -la --time-style=+%Y-%m-%d_%H:%M "$DST"
echo "md5 src: $(md5sum $SRC | cut -d" " -f1)"
echo "md5 dst: $(md5sum $DST | cut -d" " -f1)"
