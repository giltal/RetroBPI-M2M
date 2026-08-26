#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/audio_watch.sh root@$B:/tmp/aw.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i 's/\r\$//' /tmp/aw.sh
  # keep the first session's evidence
  cp /tmp/gameplay.log /tmp/gameplay_session1.log 2>/dev/null
  pkill -f 'aw.sh' 2>/dev/null; sleep 1
  rm -f /tmp/gameplay.log
  setsid nohup sh /tmp/aw.sh /tmp/gameplay.log 900 >/dev/null 2>&1 &
  sleep 3
  echo \"v2 watcher running: \$(ps w | grep '[a]w.sh' | wc -l)\"
  echo \"session1 preserved: \$(wc -l < /tmp/gameplay_session1.log) lines\"
  echo \"--- first lines of new log (should show per-second MIN trend) ---\"
  head -8 /tmp/gameplay.log
  echo \"--- game still running: \$(ps w | grep -c '[r]etroarch.bin') ---\"" 2>&1 | grep -vi warning || true
