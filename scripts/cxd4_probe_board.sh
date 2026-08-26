#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
ST=/proc/asound/card0/pcm0p/sub0/status
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
cp "$OPT" /tmp/opt.keep
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2

probe() {
  GFX="$1"; RSP="$2"; W="$3"
  sed -i "s/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = \"$GFX\"/" "$OPT"
  sed -i "s/^parallel-n64-rspplugin = .*/parallel-n64-rspplugin = \"$RSP\"/" "$OPT"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!
  sleep 8
  echo "--- gfx=$GFX rsp=$RSP (after 8s settle, ${W}s window) ---"
  echo "  pcm state: $(awk -F': *' '/^state/{print $2}' $ST 2>/dev/null || echo none)"
  H0=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  # per-thread CPU: is anything actually burning cycles?
  TOT0=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  sleep $W
  TOT1=$(awk '{print $14+$15}' /proc/$P/stat 2>/dev/null)
  H1=$(awk -F': *' '/hw_ptr/{print $2}' $ST 2>/dev/null)
  [ -z "$H0" ] && H0=0; [ -z "$H1" ] && H1=0
  [ -z "$TOT0" ] && TOT0=0; [ -z "$TOT1" ] && TOT1=0
  TICKS=$((TOT1-TOT0))
  HZ=$(getconf CLK_TCK 2>/dev/null || echo 100)
  echo "  cpu       : ${TICKS} ticks / ${W}s  = $(( TICKS * 100 / (W * HZ) ))% of one core"
  echo "  audio     : +$((H1-H0)) frames (full speed 48k = $((48000*W)))"
  echo "  threads   : $(ls /proc/$P/task 2>/dev/null | wc -l)"
  kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
}

probe angrylion cxd4 20
probe angrylion hle  20
probe rice      hle  20

cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
