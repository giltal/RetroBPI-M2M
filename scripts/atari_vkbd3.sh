#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== the option that gates L3/R3 (libretro-core.c ~1490-1515) ==="
sed -n '1488,1515p' "$D/libretro/libretro-core.c"
echo
echo "=== what option name is that? ==="
grep -n 'internal_hotkeys\|hotkey' "$D/libretro/libretro_core_options.h" | head -8
