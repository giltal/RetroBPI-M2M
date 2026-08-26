#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'ls /opt/roms/atari800/ 2>/dev/null | head -8; echo "--- count: $(ls /opt/roms/atari800/ 2>/dev/null | wc -l)"' 2>&1 | grep -vi warning
