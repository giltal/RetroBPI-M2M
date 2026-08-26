#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
CFGDIR="/root/.config/retroarch/config/ParaLLEl N64"
OVR="$CFGDIR/ParaLLEl N64.cfg"
ST=/proc/asound/card0/pcm0p/sub0/status
W=15
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g" 2>/dev/null; done
[ -f "$OVR" ] && cp "$OVR" /tmp/ovr.bak

measure() {
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 6
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
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  echo "$XR $NOTRUN"
}

for r in 1 2; do
  for L in 128 192 256 320; do
    rm -f "$OVR"; printf 'audio_latency = "%s"\n' "$L" > "$OVR"
    R=$(measure)
    printf 'round%s lat=%-5s xruns=%-4s nonRUN=%s\n' "$r" "$L" $R
  done
done
rm -f "$OVR"; [ -f /tmp/ovr.bak ] && cp /tmp/ovr.bak "$OVR"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
