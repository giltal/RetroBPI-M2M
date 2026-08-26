#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
VBL=/proc/interrupts
ST=/proc/asound/card0/pcm0p/sub0/status
W=8
vbl() { awk '/1c0c000.lcd-controller/{print $2}' $VBL; }
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
[ -f "$OPT" ] || { echo "no opt"; exit 3; }
cp "$OPT" /tmp/opt.keep
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 3
A=$(vbl); sleep $W; B=$(vbl); IDLE=$((B-A))
echo "idle vblanks/${W}s = $IDLE  (anything at or below this = presenting nothing)"
echo

run() {
  GFX="$1"; RSP="$2"
  sed -i "s/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = \"$GFX\"/" "$OPT"
  sed -i "s/^parallel-n64-rspplugin = .*/parallel-n64-rspplugin = \"$RSP\"/" "$OPT"
  grep -q '^parallel-n64-rspplugin' "$OPT" || echo "parallel-n64-rspplugin = \"$RSP\"" >> "$OPT"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 7
  V0=$(vbl); H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  sleep $W
  V1=$(vbl); H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  DV=$((V1-V0))
  VERDICT="nothing"
  [ $DV -gt $((IDLE + 40)) ] && VERDICT="PRESENTING"
  printf 'gfx=%-10s rsp=%-8s vbl+%-5s fps~%-4s audio+%-8s  %s\n' \
     "$GFX" "$RSP" "$DV" "$((DV/W))" "$((H1-H0))" "$VERDICT"
}

run rice      hle
run angrylion hle
run angrylion cxd4
run angrylion auto

cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored: $(grep -h 'gfxplugin \|rspplugin ' "$OPT" | tr '\n' ' ')"
