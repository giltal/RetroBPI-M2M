#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
GCFG=/root/.config/retroarch/retroarch.cfg
OVR="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg"
ST=/proc/asound/card0/pcm0p/sub0/status
VBL=/proc/interrupts
W=15
vbl() { awk '/1c0c000.lcd-controller/{print $2}' $VBL; }
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
echo "preconditions:"
echo "  audio_driver   : $(grep '^audio_driver' $GCFG)"
echo "  audio_latency  : $(grep '^audio_latency' $GCFG)"
echo "  N64 override   : $([ -f "$OVR" ] && echo PRESENT || echo absent-as-intended)"
echo "  governor       : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
echo

run() {
  TAG="$1"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 8
  V0=$(vbl); H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null); T0=$(cut -d. -f1 /proc/uptime)
  XR=0; LAST=$H0; i=0
  while [ $i -lt 80 ]; do
    HW=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
    [ -n "$HW" ] && [ -n "$LAST" ] && [ "$HW" -lt "$LAST" ] && XR=$((XR+1))
    [ -n "$HW" ] && LAST=$HW
    i=$((i+1))
  done
  sleep $W
  V1=$(vbl); H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null); T1=$(cut -d. -f1 /proc/uptime)
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  EL=$((T1-T0)); [ $EL -le 0 ] && EL=1
  printf '%-24s xruns=%-3s audio_rate=%-7s Hz  fps=%s\n' \
     "$TAG" "$XR" "$(( (H1-H0)/EL ))" "$(( (V1-V0)/EL ))"
}
run "round1 SHIPPED"
run "round2 SHIPPED"
run "round3 SHIPPED"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### done"
