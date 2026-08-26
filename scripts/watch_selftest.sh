#!/bin/sh
ROM="/opt/roms/n64/Mario Kart 64 (USA).zip"
CORE="/usr/lib/libretro/paralleln64_libretro.so"
if ps w | grep -q "[r]etroarch"; then echo "REFUSING: retroarch running"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
retroarch -L "$CORE" "$ROM" >/dev/null 2>&1 &
P=$!; sleep 8
sh /tmp/aw.sh /tmp/selftest.log 20 &
W=$!
T0=$(awk '{print $14+$15}' /proc/$W/stat 2>/dev/null)
sleep 20
T1=$(awk '{print $14+$15}' /proc/$W/stat 2>/dev/null)
wait $W 2>/dev/null
kill $P 2>/dev/null; sleep 2; kill -9 $P 2>/dev/null; sleep 1
: ${T0:=0}; ${T1:=0} 2>/dev/null; [ -z "$T1" ] && T1=0
echo "watcher own CPU: $((T1-T0)) ticks over 20s = $(( (T1-T0)*100/(20*100) ))% of one core"
grep '^# ' /tmp/selftest.log | tail -5
/etc/init.d/S12launcher start >/dev/null 2>&1
echo "### restored"
