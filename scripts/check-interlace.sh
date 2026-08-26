#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/pcsx_rearmed_libretro.so
echo "=== interlace-related strings in the core ==="
strings "$SO" | grep -i interlace | head -6
echo
echo "=== total pcsx_rearmed_ option keys ==="
strings "$SO" | grep -cE '^pcsx_rearmed_'
