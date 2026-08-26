#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/pcsx_rearmed_libretro.so
echo "=== option definitions mentioning Interlaced ==="
strings "$SO" | grep -E 'Interlac[^;]*; ' | head -4
echo
echo "=== nearby enumerated values ==="
strings "$SO" | grep -E '^(disabled|enabled|auto)$' | sort -u
