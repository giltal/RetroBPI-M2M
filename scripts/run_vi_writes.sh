#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O ~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so root@$B:/tmp/n64dbg.so 2>&1 | grep -vi warning
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/vi_writes_board.sh root@$B:/tmp/viw.sh 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/viw.sh; sh /tmp/viw.sh" 2>&1 | grep -vi warning
