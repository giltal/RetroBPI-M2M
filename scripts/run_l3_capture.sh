#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=45"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/l3_capture.sh root@$B:/tmp/l3.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/l3.sh; sh /tmp/l3.sh" 2>&1 | grep -vi warning || true
