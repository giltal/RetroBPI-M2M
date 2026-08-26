#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'echo "game running    : $(ps w | grep retroarch.bin | grep -v grep | wc -l)"
echo "watcher procs   : $(ps w | grep aw.sh | grep -v grep | wc -l)"
echo "log size        : $(wc -c < /tmp/gameplay.log 2>/dev/null) bytes"
echo "--- header ---"; head -3 /tmp/gameplay.log 2>/dev/null
echo "--- events so far ---"; grep -c NEWWORST /tmp/gameplay.log 2>/dev/null | sed "s/^/new-worst events: /"
grep NEWWORST /tmp/gameplay.log 2>/dev/null | tail -5
echo "--- live pcm ---"; grep -E "^state|delay|avail_max" /proc/asound/card0/pcm0p/sub0/status 2>/dev/null' 2>&1 | grep -vi warning || true
