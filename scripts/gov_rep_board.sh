#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
ST=/proc/asound/card0/pcm0p/sub0/status
W=15
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
setgov() { for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "$1" > "$g" 2>/dev/null; done; }
ORIG=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

run() {
  GOV="$1"; TAG="$2"
  setgov "$GOV"; sleep 1
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 6
  LAST=0; XR=0; NOTRUN=0; SAMP=0
  N=$(( W * 10 )); i=0
  while [ $i -lt $N ]; do
    S=$(cat $ST 2>/dev/null)
    STATE=$(echo "$S" | awk -F': *' '/^state/{print $2}')
    HW=$(echo "$S" | awk -F': *' '/hw_ptr/{print $2}')
    [ "$STATE" = "RUNNING" ] || NOTRUN=$((NOTRUN+1))
    [ -n "$HW" ] && [ "$HW" -lt "$LAST" ] && XR=$((XR+1))
    [ -n "$HW" ] && LAST=$HW
    SAMP=$((SAMP+1)); i=$((i+1))
  done
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  printf '%-12s round%s  xruns=%-4s nonRUN=%-4s samples=%s\n' "$GOV" "$TAG" "$XR" "$NOTRUN" "$SAMP"
}

for r in 1 2 3; do
  run schedutil   $r
  run performance $r
done
setgov "$ORIG"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### done, governor restored to $ORIG"
