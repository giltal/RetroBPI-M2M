#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/n64_baseline_board.sh root@$B:/tmp/bl.sh 2>&1 | grep -vi warning
ssh $O root@$B 'sed -i "s/\r$//" /tmp/bl.sh; sh /tmp/bl.sh' 2>&1 | grep -vi warning
