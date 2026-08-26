#!/bin/sh
C=/root/.config/retroarch/retroarch.cfg
echo "=== file ==="
ls -la $C
echo "=== audio lines actually present ==="
grep -n '^audio' $C || echo "  (NONE - audio_driver line is missing!)"
echo "=== any commented-out or reset driver ==="
grep -n 'audio_driver' $C || echo "  no audio_driver anywhere"
echo "=== what retroarch is actually using (from its own process) ==="
ps w | grep [r]etroarch.bin | head -2
echo "=== pcm owner ==="
grep owner_pid /proc/asound/card0/pcm0p/sub0/status 2>/dev/null
echo "=== is there a second config retroarch might prefer? ==="
ls -la /root/.config/retroarch/*.cfg 2>/dev/null
