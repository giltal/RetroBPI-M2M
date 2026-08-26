#!/bin/sh
echo "game running : $(ps w | grep retroarch.bin | grep -v grep | wc -l)"
echo "trigger file : $([ -f /tmp/dump_on ] && echo present || echo MISSING)"
S1=$(wc -c < /tmp/audio_dump.raw 2>/dev/null || echo 0)
sleep 3
S2=$(wc -c < /tmp/audio_dump.raw 2>/dev/null || echo 0)
echo "dump size    : $S1 -> $S2 bytes  (growing: $([ "$S2" -gt "$S1" ] && echo YES || echo NO))"
echo "captured     : $((S2 / 4)) frames = $((S2 / 192000)) s of 30"
echo "free in /tmp : $(df -h /tmp 2>/dev/null | tail -1)"
echo "--- latest SEC line ---"
tail -1 /tmp/glitch.log 2>/dev/null
echo "--- pcm rate (should now be 48000 end to end) ---"
grep -E '^rate' /proc/asound/card0/pcm0p/sub0/hw_params 2>/dev/null
