#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/lat_rep_board.sh root@$B:/tmp/lat.sh 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/lat.sh; sh /tmp/lat.sh" 2>&1 | grep -vi warning
