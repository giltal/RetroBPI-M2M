#!/bin/sh
# READ-ONLY. Observes the running game. Touches nothing.
ST=/proc/asound/card0/pcm0p/sub0/status
W=30
echo "=== live session ==="
ps w | grep [r]etroarch.bin | sed 's/^ *//' | cut -c1-90
echo "governor : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo "latency  : $(grep -h '^audio_latency' "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg" 2>/dev/null)"
echo "gfx/rsp  : $(grep -h 'gfxplugin \|rspplugin ' "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt" | tr '\n' ' ')"
echo
echo "=== observing ${W}s of real gameplay (read-only) ==="
LAST=0; XR=0; NOTRUN=0; N=$(( W * 10 )); i=0
while [ $i -lt $N ]; do
  S=$(cat $ST 2>/dev/null)
  STATE=$(echo "$S" | awk -F': *' '/^state/{print $2}')
  HW=$(echo "$S" | awk -F': *' '/hw_ptr/{print $2}')
  [ "$STATE" = "RUNNING" ] || NOTRUN=$((NOTRUN+1))
  [ -n "$HW" ] && [ "$HW" -lt "$LAST" ] && XR=$((XR+1))
  [ -n "$HW" ] && LAST=$HW
  i=$((i+1))
done
echo "xrun_resets = $XR   non_RUNNING = $NOTRUN / $N samples  (over ${W}s)"
echo "per-minute rate: $(( XR * 60 / W )) dropouts/min"
echo
echo "=== cpu ==="
top -b -n2 -d1 2>/dev/null | grep -E '^ *[0-9]+ root.*retroarch' | tail -1 | sed 's/^ *//' | cut -c1-70
