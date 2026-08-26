#!/bin/sh
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
VBL=/proc/interrupts
PCM=/proc/asound/card0/pcm0p/sub0/status
W=6
vbl() { awk '/1c0c000.lcd-controller/{print $2}' $VBL; }
hw()  { awk -F': *' '/hw_ptr/{print $2}' $PCM 2>/dev/null; }
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
[ -s /tmp/n64dbg.so ] || { echo "no staged core"; exit 3; }
cp "$CORE" /tmp/n64_orig.so; cp "$OPT" /tmp/opt.bak
cp /tmp/n64dbg.so "$CORE"
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 3

echo "=== idle baseline (nothing running) ==="
A=$(vbl); sleep $W; B=$(vbl); IDLE=$((B-A))
echo "idle vblanks/${W}s = $IDLE"
echo

run() {
  NAME="$1"; GFX="$2"; THR="$3"
  sed -i "s/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = \"$GFX\"/" "$OPT"
  sed -i "/^parallel-n64-angrylion-multithread/d" "$OPT"
  [ -n "$THR" ] && echo "parallel-n64-angrylion-multithread = \"$THR\"" >> "$OPT"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 6
  V0=$(vbl); A0=$(hw); sleep $W; V1=$(vbl); A1=$(hw)
  C=$(top -b -n2 -d1 2>/dev/null | awk '/retroarch/{c=$7} END{print c}')
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  [ -z "$A0" ] && A0=0; [ -z "$A1" ] && A1=0
  DV=$((V1-V0)); DA=$((A1-A0))
  printf '%-30s vbl+%-5s (idle=%s) fps~%-4s audio+%-8s cpu=%s\n' \
    "$NAME" "$DV" "$IDLE" "$((DV/W))" "$DA" "$C"
}

echo "=== full speed audio at 48kHz over ${W}s = 288000 ==="
run "rice (reference)"        "rice"      ""
run "angrylion all-threads"   "angrylion" "all threads"
run "angrylion 4 threads"     "angrylion" "4"

cp /tmp/n64_orig.so "$CORE"; cp /tmp/opt.bak "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
