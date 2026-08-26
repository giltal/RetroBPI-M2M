#!/bin/bash
set -e
O=~/bpi/output
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/psx
rm -rf "$P" && mkdir -p "$P"
cp "$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so" "$P/"
cp "$EXT/board/bpi-m2m/rootfs_overlay/root/.config/retroarch/retroarch.cfg" "$P/"
cp "$EXT/board/bpi-m2m/rootfs_overlay/root/.config/retroarch/config/PCSX-ReARMed/PCSX-ReARMed.opt" "$P/"
echo "=== staged ==="
ls -l "$P" | tail -4
echo
echo "  system_directory: $(grep -E '^system_directory' "$P/retroarch.cfg")"
echo "  option keys     : $(grep -cE '^pcsx_rearmed' "$P/PCSX-ReARMed.opt")"
