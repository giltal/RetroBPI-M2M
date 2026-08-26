#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/libretro-atari800-* | head -1)
echo "=== is atari800_vkbd_enabled declared as a core option? ==="
grep -n -A6 'atari800_vkbd_enabled' "$D/libretro/libretro_core_options.h" 2>/dev/null | head -20 || echo "  NOT DECLARED in core options"
echo
echo "=== all atari800_ options actually declared ==="
grep -o '"atari800_[a-z_]*"' "$D/libretro/libretro_core_options.h" 2>/dev/null | sort -u | head -25
echo
echo "=== how SHOWKEY is toggled by the pad button ==="
grep -n 'SHOWKEY' "$D/libretro/core-mapper.c" "$D/libretro/libretro-core.c" 2>/dev/null | head -12
