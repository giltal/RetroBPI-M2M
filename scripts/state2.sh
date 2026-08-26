#!/bin/sh
echo "=== uptime ==="; cut -d' ' -f1 /proc/uptime
echo "=== ALL processes of interest ==="
ps w | grep -E 'retroarch|retrobpi|aw\.sh' | grep -v grep
echo "=== counts ==="
echo "retroarch.bin : $(ps w | grep 'retroarch.bin' | grep -v grep | wc -l)"
echo "launcher      : $(ps w | grep 'retrobpi_launcher' | grep -v grep | wc -l)"
echo "watchers      : $(ps w | grep 'aw.sh' | grep -v grep | wc -l)"
echo "=== new log ==="
wc -l < /tmp/gameplay.log
tail -6 /tmp/gameplay.log
echo "=== pcm ==="
head -2 /proc/asound/card0/pcm0p/sub0/status
