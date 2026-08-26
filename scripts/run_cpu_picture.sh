#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/cpu_picture.sh root@$B:/tmp/cp.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/cp.sh; sh /tmp/cp.sh" 2>&1 | grep -vi warning || true
