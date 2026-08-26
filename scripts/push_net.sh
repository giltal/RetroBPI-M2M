#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay
scp $O "$R/usr/sbin/wifi-setup" root@$B:/usr/sbin/wifi-setup 2>&1 | grep -vi warning || true
ssh $O root@$B 'sed -i "s/\r$//" /usr/sbin/wifi-setup; chmod +x /usr/sbin/wifi-setup
  echo "=== wifi-setup installed ==="
  /usr/sbin/wifi-setup --status
  echo
  echo "=== hot-plug rule in place ==="
  ls -la /etc/udev/rules.d/70-net-hotplug.rules /usr/sbin/net-hotplug | sed "s/^/  /"' 2>&1 | grep -vi warning || true
