#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
ssh $O root@$B "sh /tmp/l3c.sh" 2>&1 | grep -vi warning
