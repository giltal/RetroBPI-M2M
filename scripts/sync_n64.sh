#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
T=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
# refuse to ship an instrumented core
if strings "$T" | grep -qE 'RAW n=|astick.log|glitch.log|speed_permille'; then
  echo "ABORT: build-tree core still contains instrumentation"; exit 3
fi
echo "build-tree core verified clean"
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O "$T" root@$B:/tmp/n64.so 2>&1 | grep -vi warning
ssh $O root@$B 'cp /tmp/n64.so /usr/lib/libretro/paralleln64_libretro.so; rm -f /tmp/n64.so
  echo "board md5 : $(md5sum /usr/lib/libretro/paralleln64_libretro.so | cut -d" " -f1)"
  echo "instrumentation: $(strings /usr/lib/libretro/paralleln64_libretro.so | grep -cE "RAW n=|astick.log") (must be 0)"' 2>&1 | grep -vi warning
echo "image md5 : $(md5sum $T | cut -d' ' -f1)"
