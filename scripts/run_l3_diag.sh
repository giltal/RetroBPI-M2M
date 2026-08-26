#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/l3_diag.sh root@$B:/tmp/l3d.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/l3d.sh; sh /tmp/l3d.sh" 2>&1 | grep -vi warning || true
