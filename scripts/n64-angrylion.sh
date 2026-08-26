#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "=== angrylion option definitions (Description; values) ==="
strings "$SO" | grep -iE 'angrylion|multi.?thread|Multi-threading' | head -12
echo
echo "=== the option keys ==="
strings "$SO" | grep -E '^parallel-n64-angrylion'
echo
echo "=== thread-count style values nearby ==="
strings "$SO" | grep -E '^(all|[0-9]+)$' | sort -u | head -12
