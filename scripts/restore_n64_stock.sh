#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
ssh $O root@$B '[ -f /tmp/n64_stock.so ] && cp /tmp/n64_stock.so /usr/lib/libretro/paralleln64_libretro.so
  rm -f /tmp/astick.log /tmp/n64_stock.so
  echo "instrumentation on board: $(strings /usr/lib/libretro/paralleln64_libretro.so | grep -cE "RAW n=|astick.log") (must be 0)"
  echo "core md5 : $(md5sum /usr/lib/libretro/paralleln64_libretro.so | cut -d" " -f1)"' 2>&1 | grep -vi warning
