#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
CFGDIR="/root/.config/retroarch/config/ParaLLEl N64"
OVR="$CFGDIR/ParaLLEl N64.cfg"
ST=/proc/asound/card0/pcm0p/sub0/status
W=15
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
[ -f "$OVR" ] && cp "$OVR" /tmp/ovr.keep

run() {
  NAME="$1"; shift
  rm -f "$OVR"
  for kv in "$@"; do echo "$kv" >> "$OVR"; done
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 7
  H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  LAST=0; XR=0; RUN=0; N=$(( W * 10 )); i=0
  while [ $i -lt $N ]; do
    S=$(cat $ST 2>/dev/null)
    [ "$(echo "$S" | awk -F': *' '/^state/{print $2}')" = "RUNNING" ] && RUN=$((RUN+1))
    HW=$(echo "$S" | awk -F': *' '/hw_ptr/{print $2}')
    [ -n "$HW" ] && [ "$HW" -lt "$LAST" ] && XR=$((XR+1))
    [ -n "$HW" ] && LAST=$HW
    i=$((i+1))
  done
  H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  D=$((H1-H0)); EXP=$((48000*W))
  printf '%-30s xruns=%-3s running=%s/%s audio=+%-8s (expect ~%s)\n' \
     "$NAME" "$XR" "$RUN" "$N" "$D" "$EXP"
}

for r in 1 2 3; do
  echo "--- round $r ---"
  run "alsa       lat256" 'audio_latency = "256"'
  run "alsathread lat128" 'audio_latency = "128"' 'audio_driver = "alsathread"'
  run "alsathread lat256" 'audio_latency = "256"' 'audio_driver = "alsathread"'
done
rm -f "$OVR"; [ -f /tmp/ovr.keep ] && cp /tmp/ovr.keep "$OVR"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
