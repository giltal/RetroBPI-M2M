#!/bin/bash
# Start the read-only audio watcher on the board while a game is being played.
#   usage: watch_gameplay.sh [start SECONDS | collect]
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ACT=${1:-start}
DUR=${2:-900}

case "$ACT" in
start)
  scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/audio_watch.sh root@$B:/tmp/aw.sh 2>&1 | grep -vi warning || true
  ssh $O root@$B "sed -i 's/\r\$//' /tmp/aw.sh
    if ! ps w | grep -q '[r]etroarch'; then echo 'NOTE: no game running yet - watcher only counts RUNNING samples'; fi
    rm -f /tmp/gameplay.log
    setsid nohup sh /tmp/aw.sh /tmp/gameplay.log $DUR >/dev/null 2>&1 &
    sleep 1
    echo \"watcher started for ${DUR}s, logging to /tmp/gameplay.log\"
    ps w | grep -c '[a]w.sh' | sed 's/^/watcher procs: /'" 2>&1 | grep -vi warning || true
  ;;
collect)
  ssh $O root@$B 'echo "=== summary ==="; grep "^# " /tmp/gameplay.log | tail -6
    echo "=== full underruns (stream reset) ==="
    grep RESET /tmp/gameplay.log | head -20
    echo "  total resets: $(grep -c RESET /tmp/gameplay.log)"
    echo "=== NEW WORST margin events (kernel avail_max, cannot miss any) ==="
    grep NEWWORST /tmp/gameplay.log | tail -25
    echo "  total new-worst events: $(grep -c NEWWORST /tmp/gameplay.log)"
    echo "=== sampled margin dips below one period ==="
    grep -vE "^#|RESET|NEWWORST" /tmp/gameplay.log | head -25
    echo "  total dips: $(grep -vcE "^#|RESET|NEWWORST" /tmp/gameplay.log)"
    echo "=== still running? ==="; ps w | grep -c "[a]w.sh"' 2>&1 | grep -vi warning || true
  ;;
esac
