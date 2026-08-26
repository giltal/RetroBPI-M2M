#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
T=~/bpi/output/target/usr/lib/libretro/atari800_libretro.so
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O "$T" root@$B:/tmp/at.so 2>&1 | grep -vi warning
ssh $O root@$B 'cp /tmp/at.so /usr/lib/libretro/atari800_libretro.so; rm -f /tmp/at.so
  echo "board md5 now : $(md5sum /usr/lib/libretro/atari800_libretro.so | cut -d" " -f1)"
  echo "R-patch present: $(strings /usr/lib/libretro/atari800_libretro.so | grep -c "Virtual Keyboard (alt)")"' 2>&1 | grep -vi warning
echo "image md5     : $(md5sum $T | cut -d' ' -f1)"
