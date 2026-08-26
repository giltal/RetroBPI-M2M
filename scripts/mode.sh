#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'cat /sys/class/drm/*/modes 2>/dev/null | head -3' 2>&1 | grep -vi warning
