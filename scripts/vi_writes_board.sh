#!/bin/sh
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
[ -s /tmp/n64dbg.so ] || { echo "no staged core"; exit 3; }
cp "$CORE" /tmp/n64_orig.so; cp "$OPT" /tmp/opt.bak
cp /tmp/n64dbg.so "$CORE"
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

run() {
  GFX="$1"
  sed -i "s/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = \"$GFX\"/" "$OPT"
  rm -f /tmp/vi_writes.txt
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!; sleep 15
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
  echo "===================== gfxplugin=$GFX ====================="
  if [ -f /tmp/vi_writes.txt ]; then
    echo "-- writes to ORIGIN(reg=1) --"
    grep 'reg=1 ' /tmp/vi_writes.txt | head -6
    echo "   count: $(grep -c 'reg=1 ' /tmp/vi_writes.txt)"
    echo "-- writes to H_START(reg=9) --"
    grep 'reg=9 ' /tmp/vi_writes.txt | head -6
    echo "   count: $(grep -c 'reg=9 ' /tmp/vi_writes.txt)"
    echo "-- total VI writes seen (from totalvi field) --"
    tail -1 /tmp/vi_writes.txt
  else
    echo "NO /tmp/vi_writes.txt -- write_vi_regs never called at all"
  fi
}

run rice
run angrylion

cp /tmp/n64_orig.so "$CORE"; cp /tmp/opt.bak "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
