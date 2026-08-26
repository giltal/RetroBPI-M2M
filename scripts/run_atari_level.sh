#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
scp $O ~/bpi/output/target/usr/bin/retroarch.bin root@$B:/tmp/ra_new.bin 2>&1 | grep -vi warning || true
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/atari_level_board.sh root@$B:/tmp/al.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "cp /usr/bin/retroarch.bin /tmp/ra_orig.bin; cp /tmp/ra_new.bin /usr/bin/retroarch.bin; sed -i \"s/\r\$//\" /tmp/al.sh; sh /tmp/al.sh" 2>&1 | grep -vi warning || true
