#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8"
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/n64_vioverlay_board.sh
scp $O "$P" root@$B:/tmp/vio.sh 2>&1 | grep -vi warning
ssh $O root@$B 'sed -i "s/\r$//" /tmp/vio.sh; chmod +x /tmp/vio.sh
if ps w | grep -q "[r]etroarch"; then echo "GAME RUNNING - ABORT"; exit 2; fi
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
sh /tmp/vio.sh
echo "=== restarting launcher ==="; /etc/init.d/S12launcher start >/dev/null 2>&1; sleep 1; ps w | grep -c "[r]etrobpi_launcher"' 2>&1 | grep -vi warning
