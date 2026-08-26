#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/verify_instr.sh root@$B:/tmp/vi.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/vi.sh; sh /tmp/vi.sh" 2>&1 | grep -vi warning || true
