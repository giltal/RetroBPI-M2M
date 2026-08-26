#!/bin/sh
echo "=== uptime now ==="; cut -d' ' -f1 /proc/uptime
echo "=== watcher alive? ==="; ps w | grep [a]w.sh | head -2
echo "=== FULL log (every line) ==="; cat /tmp/gameplay.log
echo "=== live pcm status ==="; cat /proc/asound/card0/pcm0p/sub0/status
echo "=== game ==="; ps w | grep [r]etroarch.bin | cut -c1-80
