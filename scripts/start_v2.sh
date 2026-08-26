#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/audio_watch.sh root@$B:/tmp/aw.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i 's/\r\$//' /tmp/aw.sh
  # stop any leftovers by PID (busybox pkill is a no-op here)
  for p in \$(ps w | grep 'aw\.sh' | grep -v grep | awk '{print \$1}'); do kill -9 \$p 2>/dev/null; done
  sleep 1
  [ -f /tmp/gameplay.log ] && cp /tmp/gameplay.log /tmp/gameplay_prev.log
  rm -f /tmp/gameplay.log
  setsid nohup sh /tmp/aw.sh /tmp/gameplay.log 1200 >/dev/null 2>&1 &
  sleep 4
  echo \"watchers running : \$(ps w | grep 'aw\.sh' | grep -v grep | wc -l)  (must be 1)\"
  echo \"game running     : \$(ps w | grep 'retroarch.bin' | grep -v grep | wc -l)\"
  echo \"log lines so far : \$(wc -l < /tmp/gameplay.log)\"
  echo '--- proof it is sampling (per-second MIN lines) ---'
  grep ' MIN ' /tmp/gameplay.log | tail -3
  echo '--- header ---'
  head -2 /tmp/gameplay.log" 2>&1 | grep -vi warning || true
