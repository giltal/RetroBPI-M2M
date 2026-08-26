#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/atari_native_board.sh root@$B:/tmp/an2.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/an2.sh; sh /tmp/an2.sh" 2>&1 | grep -vi warning || true
