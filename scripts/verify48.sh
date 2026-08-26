#!/bin/sh
C=/usr/lib/libretro/paralleln64_libretro.so
echo "core markers : $(strings $C | grep -c 'float_permille')"
rm -f /tmp/glitch.log
echo "log cleared"
echo "--- current ALSA state (48000 expected once a game runs) ---"
grep -E '^rate' /proc/asound/card0/pcm0p/sub0/hw_params 2>/dev/null || echo "  (closed - will show when playing)"
echo "--- headphone volume ---"
amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep -m1 '^  : values'
