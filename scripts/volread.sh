#!/bin/sh
for f in /root/.retrobpi_state /root/.retrobpi/state /var/lib/retrobpi/state; do
  [ -f "$f" ] && { echo "found: $f"; cat "$f"; }
done
echo "--- any state-ish files under /root ---"
ls -la /root/ 2>/dev/null | head -12
echo "--- current mixer ---"
amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep ': values'
