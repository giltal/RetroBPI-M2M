#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
W=45
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
[ -s /tmp/n64dbg.so ] || { echo "no staged core"; exit 3; }
cp "$CORE" /tmp/n64_orig.so; cp "$OPT" /tmp/opt.keep
cp /tmp/n64dbg.so "$CORE"
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

setopt() {
  k="$1"; v="$2"
  if grep -q "^$k" "$OPT"; then sed -i "s|^$k = .*|$k = \"$v\"|" "$OPT"
  else echo "$k = \"$v\"" >> "$OPT"; fi
}

run() {
  NAME="$1"; ALIST="$2"; BUFSZ="$3"
  setopt parallel-n64-send_allist_to_hle_rsp "$ALIST"
  setopt parallel-n64-audio-buffer-size "$BUFSZ"
  rm -f /tmp/glitch.log
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!
  sleep $W
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  # last SEC line carries the cumulative totals
  LAST=$(grep '^SEC ' /tmp/glitch.log 2>/dev/null | tail -1)
  FR=$(echo "$LAST" | sed -n 's/.*frames=\([0-9]*\).*/\1/p')
  GL=$(echo "$LAST" | sed -n 's/.*glitches=\([0-9]*\).*/\1/p')
  : ${FR:=0}; : ${GL:=0}
  SECS=$(( FR / 44100 ))
  [ $SECS -le 0 ] && SECS=1
  printf '%-34s frames=%-9s glitches=%-6s = %s per second of audio\n' \
     "$NAME" "$FR" "$GL" "$((GL / SECS))"
  cp /tmp/glitch.log "/tmp/glitch_$4.log" 2>/dev/null
}

echo "=== glitch counts (sample-to-sample jumps > 12000) over ${W}s each ==="
run "allist=enabled buf=2048 (shipped)" enabled  2048 a
run "allist=disabled buf=2048"          disabled 2048 b
run "allist=enabled buf=4096"           enabled  4096 c
run "allist=disabled buf=4096"          disabled 4096 d

cp /tmp/n64_orig.so "$CORE"; cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored: $(grep -h 'allist\|audio-buffer' "$OPT" | tr '\n' ' ')"
