#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
S=/mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts
for f in l3_start:l3s l3_collect:l3c; do
  src=${f%%:*}; dst=${f##*:}
  scp $O "$S/$src.sh" "root@$B:/tmp/$dst.sh" 2>&1 | grep -vi warning
  rc=$?
  echo "copied $src.sh -> /tmp/$dst.sh (exit $rc)"
done
ssh $O root@$B 'sed -i "s/\r$//" /tmp/l3s.sh /tmp/l3c.sh 2>/dev/null
  ls -la /tmp/l3s.sh /tmp/l3c.sh
  sh /tmp/l3s.sh' 2>&1 | grep -vi warning
