#!/bin/bash
# Collect everything that changed into firmware/push/ for scp to the board.
set -e
O=~/bpi/output
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/push
rm -rf $P && mkdir -p $P/libretro $P/racfg
cp $O/target/usr/lib/libretro/*.so           $P/libretro/
cp $O/target/usr/bin/retrobpi_launcher       $P/
cp -r $O/target/root/.config/retroarch/*     $P/racfg/
echo "=== staged ==="
echo "  cores   : $(ls $P/libretro/*.so | wc -l)  ($(du -sh $P/libretro | cut -f1))"
echo "  launcher: $(ls -l $P/retrobpi_launcher | awk '{print $5}') bytes"
echo "  racfg   :"
find $P/racfg -type f -print0 | while IFS= read -r -d '' f; do echo "      ${f#$P/racfg/}"; done
echo "  total   : $(du -sh $P | cut -f1)"
