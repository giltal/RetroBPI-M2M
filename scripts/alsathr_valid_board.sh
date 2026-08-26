#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
CFGDIR="/root/.config/retroarch/config/ParaLLEl N64"
OVR="$CFGDIR/ParaLLEl N64.cfg"
ST=/proc/asound/card0/pcm0p/sub0/status
HWP=/proc/asound/card0/pcm0p/sub0/hw_params
VBL=/proc/interrupts
W=15
vbl() { awk '/1c0c000.lcd-controller/{print $2}' $VBL; }
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 3
A=$(vbl); sleep 6; B=$(vbl); IDLE6=$((B-A))
echo "idle vblanks/6s = $IDLE6"
[ -f "$OVR" ] && cp "$OVR" /tmp/ovr.keep

run() {
  NAME="$1"; shift
  rm -f "$OVR"; for kv in "$@"; do echo "$kv" >> "$OVR"; done
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 8
  echo "--- $NAME ---"
  echo "  hw_params:"; sed 's/^/    /' $HWP 2>/dev/null | head -8
  V0=$(vbl); H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  A0=$(awk -F': *' '/appl_ptr/{print $2}' $ST 2>/dev/null)
  sleep $W
  V1=$(vbl); H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  A1=$(awk -F': *' '/appl_ptr/{print $2}' $ST 2>/dev/null)
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  [ -z "$A0" ] && A0=0; [ -z "$A1" ] && A1=0
  DV=$((V1-V0))
  echo "  vblanks +$DV over ${W}s -> $((DV/W)) fps   (idle rate would be $((IDLE6*W/6/W)) fps-equiv)"
  echo "  hw_ptr  +$((H1-H0))   appl_ptr +$((A1-A0))   real-time would be $((48000*W))"
  echo "  effective rate: $(( (H1-H0) / W )) Hz  (expect 48000)"
}

run "alsathread lat128" 'audio_latency = "128"' 'audio_driver = "alsathread"'
run "alsa       lat256" 'audio_latency = "256"'

rm -f "$OVR"; [ -f /tmp/ovr.keep ] && cp /tmp/ovr.keep "$OVR"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
