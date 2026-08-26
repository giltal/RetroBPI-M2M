#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
scp $O "$R/usr/sbin/net-hotplug" root@$B:/usr/sbin/net-hotplug 2>&1 | grep -vi warning || true
scp $O "$R/etc/udev/rules.d/70-net-hotplug.rules" root@$B:/etc/udev/rules.d/70-net-hotplug.rules 2>&1 | grep -vi warning || true
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/test_hotplug.sh root@$B:/tmp/th.sh 2>&1 | grep -vi warning || true
ssh $O root@$B 'sed -i "s/\r$//" /usr/sbin/net-hotplug /etc/udev/rules.d/70-net-hotplug.rules /tmp/th.sh
  chmod +x /usr/sbin/net-hotplug; sh /tmp/th.sh' 2>&1 | grep -vi warning || true
