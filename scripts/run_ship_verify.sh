#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
scp $O "$R/root/.config/retroarch/retroarch.cfg" root@$B:/root/.config/retroarch/retroarch.cfg 2>&1 | grep -vi warning
ssh $O root@$B 'rm -f "/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.cfg"' 2>&1 | grep -vi warning
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/ship_verify_board.sh root@$B:/tmp/sv.sh 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/sv.sh; sh /tmp/sv.sh" 2>&1 | grep -vi warning
