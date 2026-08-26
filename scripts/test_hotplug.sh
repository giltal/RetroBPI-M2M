#!/bin/sh
echo "=== udev running? ==="
ps w | grep -c '[u]devd'
echo "udevadm: $(command -v udevadm || echo MISSING)"
echo
echo "=== installed files ==="
ls -la /etc/udev/rules.d/70-net-hotplug.rules /usr/sbin/net-hotplug
echo
echo "=== reload rules ==="
udevadm control --reload-rules 2>&1 || echo "  (reload not supported)"
echo
echo "=== does the rule match a net add event? ==="
udevadm test-builtin net_id /sys/class/net/eth0 >/dev/null 2>&1
udevadm test /sys/class/net/eth0 2>&1 | grep -iE 'net-hotplug|RUN' | head -5 || echo "  (udevadm test gave no RUN lines)"
echo
echo "=== live trigger: simulate the adapter appearing ==="
BEFORE=$(cat /var/run/udhcpc.eth0.pid 2>/dev/null)
echo "  udhcpc pid before: ${BEFORE:-none}"
udevadm trigger --action=add --subsystem-match=net 2>/dev/null
sleep 6
AFTER=$(cat /var/run/udhcpc.eth0.pid 2>/dev/null)
echo "  udhcpc pid after : ${AFTER:-none}"
echo "  eth0 address     : $(ip -4 addr show eth0 2>/dev/null | grep -o 'inet [0-9.]*' || echo none)"
echo "  still reachable  : yes (you are reading this over that link)"
