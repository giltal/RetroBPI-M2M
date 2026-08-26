#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
OPT="/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
cp "$OPT" /tmp/opt.keep
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
dmesg -c >/dev/null 2>&1

t() {
  RSP="$1"
  sed -i 's/^parallel-n64-gfxplugin = .*/parallel-n64-gfxplugin = "angrylion"/' "$OPT"
  sed -i "s/^parallel-n64-rspplugin = .*/parallel-n64-rspplugin = \"$RSP\"/" "$OPT"
  retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
  P=$!
  ALIVE=""
  for s in 1 2 3 4 5 6 7 8 9 10; do
    sleep 1
    if [ -d /proc/$P ]; then ALIVE="$ALIVE."; else ALIVE="$ALIVE DIED@${s}s"; break; fi
  done
  if [ -d /proc/$P ]; then
    kill $P 2>/dev/null; sleep 1; kill -9 $P 2>/dev/null
    echo "rsp=$RSP : survived 10s  [$ALIVE]"
  else
    wait $P 2>/dev/null; RC=$?
    echo "rsp=$RSP : $ALIVE  exit_code=$RC"
  fi
  sleep 1
}

t cxd4
t hle
echo "=== kernel messages during the above ==="
dmesg 2>/dev/null | tail -12
cp /tmp/opt.keep "$OPT"
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
