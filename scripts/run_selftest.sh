#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts
scp $O "$R/audio_watch.sh" root@$B:/tmp/aw.sh 2>&1 | grep -vi warning || true
scp $O "$R/watch_selftest.sh" root@$B:/tmp/st.sh 2>&1 | grep -vi warning || true
ssh $O root@$B 'sed -i "s/\r$//" /tmp/aw.sh /tmp/st.sh; sh /tmp/st.sh' 2>&1 | grep -vi warning || true
