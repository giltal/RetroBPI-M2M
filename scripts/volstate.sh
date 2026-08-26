#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
ssh $O root@$B 'echo "settings file:"; cat /root/.retrobpi/settings 2>/dev/null || find /root -name "settings*" 2>/dev/null | head -3; echo "current hp index: $(amixer -c 0 cget name=\"Headphone Playback Volume\" | grep -m1 \": values\" | cut -d= -f2)"' 2>&1 | grep -vi warning
