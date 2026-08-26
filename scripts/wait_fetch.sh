#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
prev=0
for i in $(seq 1 30); do
  cur=$(ssh $O root@$B 'wc -c < /tmp/audio_dump.raw 2>/dev/null || echo 0' 2>/dev/null | tr -d '[:space:]')
  [ -z "$cur" ] && cur=0
  if [ "$cur" = "$prev" ] && [ "$cur" -gt 1000000 ]; then break; fi
  prev=$cur
  sleep 4
done
ssh $O root@$B 'rm -f /tmp/dump_on' 2>&1 | grep -vi warning || true
scp $O root@$B:/tmp/audio_dump.raw /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/audio_dump.raw 2>&1 | grep -vi warning || true
ls -la /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/audio_dump.raw
