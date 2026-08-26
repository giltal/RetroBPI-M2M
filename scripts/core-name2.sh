#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "=== strings containing 'aralle' (core display name lives here) ==="
strings "$SO" | grep -i 'aralle' | head -10
echo
echo "=== dynarec present? ==="
strings "$SO" | grep -iE 'dynamic_recompiler|dynarec|new_dynarec' | head -6
echo
echo "=== all cpucore option values (context around the key) ==="
strings "$SO" | grep -A6 -E '^parallel-n64-cpucore$' | head -12
echo
echo "=== library version / name pair ==="
strings "$SO" | grep -iE '^N64$|Nintendo 64|libretro' | head -8
echo
echo "=== size ==="
ls -l "$SO"
