#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
ssh $O root@$B 'echo "uptime : $(cut -d. -f1 /proc/uptime)s"; echo "evtest : $(ps w | grep -c "[e]vtest")"; echo "tmp free:"; df -h /tmp | tail -1; echo "tmp files:"; ls -la /tmp/ | head -20; echo "launcher: $(ps w | grep -c "[r]etrobpi_launcher")"' 2>&1 | grep -vi warning
