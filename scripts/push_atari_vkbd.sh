#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O ~/bpi/output/target/usr/lib/libretro/atari800_libretro.so root@$B:/tmp/at_new.so 2>&1 | grep -vi warning
scp $O "$R/root/.config/retroarch/config/Atari800/Atari800.opt" \
      "root@$B:'/root/.config/retroarch/config/Atari800/Atari800.opt'" 2>&1 | grep -vi warning
ssh $O root@$B 'cp /tmp/at_new.so /usr/lib/libretro/atari800_libretro.so
  rm -f /tmp/at_new.so
  echo "--- on board ---"
  echo "core md5   : $(md5sum /usr/lib/libretro/atari800_libretro.so | cut -d" " -f1)"
  echo "vkbd option: $(grep -h "^atari800_vkbd_enabled" "/root/.config/retroarch/config/Atari800/Atari800.opt")"
  echo "audio gain : $(grep -h "^audio_volume" "/root/.config/retroarch/config/Atari800/Atari800.cfg")"' 2>&1 | grep -vi warning
echo "expected core md5: $(md5sum ~/bpi/output/target/usr/lib/libretro/atari800_libretro.so | cut -d' ' -f1)"
