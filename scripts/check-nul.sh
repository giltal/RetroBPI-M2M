#!/bin/bash
for f in /mnt/c/BananaPi_Projects/RetroBPI_M2M/launcher/launcher.c \
         ~/bpi/output/build/retrobpi-launcher-local/launcher.c; do
    total=$(wc -c < "$f")
    stripped=$(tr -d '\000' < "$f" | wc -c)
    echo "  $(basename $(dirname $f))/launcher.c : $total bytes, $((total - stripped)) NUL byte(s)"
done
