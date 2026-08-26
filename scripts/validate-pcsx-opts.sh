#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/pcsx_rearmed_libretro.so
OPT="/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay/root/.config/retroarch/config/PCSX-ReARMed/PCSX-ReARMed.opt"
echo "=== every key we ship, checked against the built core ==="
missing=0
while IFS= read -r line; do
    case "$line" in \#*|"") continue;; esac
    key=${line%% =*}
    if strings "$SO" | grep -qx "$key"; then
        printf "  OK      %s\n" "$key"
    else
        printf "  ABSENT  %s   <-- inert, core does not know this key\n" "$key"
        missing=$((missing+1))
    fi
done < "$OPT"
echo "  --- $missing stale key(s) ---"
