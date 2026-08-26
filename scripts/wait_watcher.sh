#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
# poll gently (every 20s) until the watcher exits; it is a 900s run
while true; do
  n=$(ssh $O root@$B 'ps w | grep aw.sh | grep -v grep | wc -l' 2>/dev/null | tr -d "[:space:]")
  [ "$n" = "0" ] && break
  sleep 20
done
echo "watcher finished"
