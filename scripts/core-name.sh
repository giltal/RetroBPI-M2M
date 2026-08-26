#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "=== core display name (used for config/<name>/<name>.opt) ==="
strings "$SO" | grep -iE '^ParaLLEl|^parallel.?n64$|N64$' | head -5
echo
echo "=== its gfx plugin / cpu core option keys and allowed values ==="
strings "$SO" | grep -E '^parallel-n64-(gfxplugin|cpucore|screensize|framerate|rspplugin)$' | head
echo "--- values seen for gfxplugin ---"
strings "$SO" | grep -iE '^(auto|glide64|rice|angrylion|parallel)$' | sort -u | head
echo "--- values seen for cpucore ---"
strings "$SO" | grep -E '^(dynamic_recompiler|cached_interpreter|pure_interpreter)$' | sort -u
