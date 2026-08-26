#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/alsathr_valid_board.sh root@$B:/tmp/av.sh 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/av.sh; sh /tmp/av.sh" 2>&1 | grep -vi warning
