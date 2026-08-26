#!/bin/sh
ST=/proc/asound/card0/pcm0p/sub0/status
GCFG=/root/.config/retroarch/retroarch.cfg
W=12
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
cp "$GCFG" /tmp/gcfg.keep

setdrv() {
  sed -i "s/^audio_driver = .*/audio_driver = \"$1\"/" "$GCFG"
  grep -q '^audio_driver' "$GCFG" || echo "audio_driver = \"$1\"" >> "$GCFG"
}

# time-based window so the sampling loop cannot distort the measurement
probe() {
  CORE="$1"; ROM="$2"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 7
  H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  T0=$(cut -d. -f1 /proc/uptime)
  XR=0; LAST=$H0; i=0
  while [ $i -lt 60 ]; do
    HW=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
    [ -n "$HW" ] && [ -n "$LAST" ] && [ "$HW" -lt "$LAST" ] && XR=$((XR+1))
    [ -n "$HW" ] && LAST=$HW
    i=$((i+1))
  done
  sleep $W
  H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  T1=$(cut -d. -f1 /proc/uptime)
  ALIVE=$([ -d /proc/$P ] && echo yes || echo DEAD)
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  EL=$((T1-T0)); [ $EL -le 0 ] && EL=1
  echo "$XR $(( (H1-H0) / EL )) $ALIVE"
}

for DRV in alsa alsathread; do
  setdrv $DRV
  echo "=== audio_driver = $DRV ==="
  for e in \
    "NES:fceumm_libretro.so:/opt/roms/nes/1942 (Japan, USA).nes" \
    "SNES:snes9x2005_libretro.so:/opt/roms/snes/ActRaiser (USA).sfc" \
    "GBA:gpsp_libretro.so:/opt/roms/gba/001 Pokemon Fire Red.gba" \
    "PSX:pcsx_rearmed_libretro.so:/opt/roms/psx/01.CAPCOM VS SNK millennium battle.PBP" \
    "N64:paralleln64_libretro.so:/opt/roms/n64/Mario Kart 64 (USA).zip" ; do
    NAME=$(echo "$e" | cut -d: -f1)
    CORE=/usr/lib/libretro/$(echo "$e" | cut -d: -f2)
    ROM=$(echo "$e" | cut -d: -f3-)
    R=$(probe "$CORE" "$ROM")
    set -- $R
    printf '  %-5s xruns=%-3s rate=%-7s Hz (want 48000) alive=%s\n' "$NAME" "$1" "$2" "$3"
  done
done
cp /tmp/gcfg.keep "$GCFG"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored: $(grep '^audio_driver' $GCFG)"
