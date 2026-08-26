#!/bin/bash
# Push the freshly built zImage to the board and reboot into it.
#
# Keeps the previous kernel as /boot/zImage.prev. If the new one does not boot,
# the recovery is a serial console + "mv zImage.prev zImage" from U-Boot's
# rescue, or reflashing the card -- so the .prev copy is worth the 6 MB.
set -e
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
Z=/home/giltal/bpi/output/images/zImage

wsl bash -c "ls -la $Z"
wsl bash -c "md5sum $Z"

wsl bash -c "scp $O $Z root@$B:/tmp/zImage.new"
ssh $O root@$B 'sh -s' <<'RMT'
set -e
[ -s /tmp/zImage.new ] || { echo "FATAL: empty upload"; exit 1; }
cp /boot/zImage /boot/zImage.prev
mv /tmp/zImage.new /boot/zImage
sync
echo "installed: $(md5sum /boot/zImage)"
echo "rebooting"
(sleep 1; reboot) >/dev/null 2>&1 &
RMT
echo "waiting for board..."
for i in $(seq 1 30); do
  sleep 5
  if ssh $O -o ConnectTimeout=5 root@$B 'echo up' >/dev/null 2>&1; then
    echo "back after ~$((i*5))s"; break
  fi
done
