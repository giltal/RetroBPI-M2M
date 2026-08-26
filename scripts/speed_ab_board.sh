#!/bin/sh
# A/B settings against the REAL metric (emulation speed), using Mario Kart's
# attract-mode demo so the load is actual racing, not the title screen.
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
cp "$OPT" /tmp/opt.keep
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

setopt() {
  if grep -q "^$1" "$OPT"; then sed -i "s|^$1 = .*|$1 = \"$2\"|" "$OPT"
  else echo "$1 = \"$2\"" >> "$OPT"; fi
}

run() {
  NAME="$1"; GFX="$2"; SIZE="$3"; FR="$4"
  setopt parallel-n64-gfxplugin "$GFX"
  setopt parallel-n64-screensize "$SIZE"
  setopt parallel-n64-framerate "$FR"
  rm -f /tmp/glitch.log
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!
  sleep 75                      # title + let the attract demo get going
  # measure only the last stretch, which is demo racing
  MARK=$(grep -c '^SEC' /tmp/glitch.log 2>/dev/null)
  sleep 40
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  AVG=$(grep '^SEC' /tmp/glitch.log 2>/dev/null | tail -n +$((MARK+1)) \
        | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' \
        | awk '{s+=$1;n++} END{if(n)print int(s/n); else print 0}')
  WORST=$(grep '^SEC' /tmp/glitch.log 2>/dev/null | tail -n +$((MARK+1)) \
        | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | sort -n | head -1)
  printf '%-36s avg_speed=%-5s worst=%-5s\n' "$NAME" "${AVG:-0}" "${WORST:-0}"
}

echo "=== emulation speed during attract-demo racing (1000 = real time) ==="
run "rice 640x480 original (shipped)" rice     640x480 original
run "rice 320x240 original"           rice     320x240 original
run "glide64 640x480 original"        glide64  640x480 original
run "rice 640x480 fullspeed"          rice     640x480 fullspeed

cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
