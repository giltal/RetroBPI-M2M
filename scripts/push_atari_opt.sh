#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O "$R/root/.config/retroarch/config/Atari800/Atari800.opt" \
      "root@$B:'/root/.config/retroarch/config/Atari800/Atari800.opt'" 2>&1 | grep -vi warning || true
ssh $O root@$B 'echo "--- Atari800 config dir on board ---"
  ls -la "/root/.config/retroarch/config/Atari800/"
  echo "--- vkbd option ---"
  grep -h vkbd "/root/.config/retroarch/config/Atari800/Atari800.opt"' 2>&1 | grep -vi warning || true
