#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
T=~/bpi/output/target/usr/lib/libretro/fuse_libretro.so
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O "$T" root@$B:/tmp/fuse.so 2>&1 | grep -vi warning
ssh $O root@$B 'cp /tmp/fuse.so /usr/lib/libretro/fuse_libretro.so; rm -f /tmp/fuse.so
  echo "--- on board ---"
  echo "fuse md5 : $(md5sum /usr/lib/libretro/fuse_libretro.so | cut -d" " -f1)"
  echo "fuse.cfg : $(grep -h device_p1 /root/.config/retroarch/config/fuse/fuse.cfg 2>/dev/null)"
  echo "fuse.opt : $(grep -h machine /root/.config/retroarch/config/fuse/fuse.opt 2>/dev/null)"
  echo "config dir case: $(ls -d /root/.config/retroarch/config/[Ff]use 2>/dev/null)"' 2>&1 | grep -vi warning
echo "expected md5: $(md5sum $T | cut -d' ' -f1)"
