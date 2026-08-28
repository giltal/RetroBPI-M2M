#!/bin/bash
set -e
I=/home/giltal/bpi/output/images/sdcard.img
FW=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
cp "$I" "$FW"
echo "img md5 : $(md5sum "$I" | cut -d' ' -f1)"
echo "fw  md5 : $(md5sum "$FW" | cut -d' ' -f1)"
