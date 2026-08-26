#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }
scp $O "$R/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt" \
      "root@$B:'/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt'" 2>&1 | grep -vi warning
ssh $O root@$B 'echo "--- on board ---"
  grep -hE "^parallel-n64-(astick|screensize|gfxplugin )" "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt"' 2>&1 | grep -vi warning
