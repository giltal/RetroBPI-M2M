#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so root@$B:/tmp/n64dbg.so 2>&1 | grep -vi warning || true
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/glitch_ab_board.sh root@$B:/tmp/gab.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/gab.sh; sh /tmp/gab.sh" 2>&1 | grep -vi warning || true
