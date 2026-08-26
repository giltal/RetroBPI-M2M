#!/bin/bash
# Push kernel + extlinux. Keeps a backup entry so a bad kernel is recoverable
# from the serial console rather than requiring a card reflash.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
I=~/bpi/output/images
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay

RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" != "0" ] && { echo "ABORT: a game is running"; exit 2; }

echo "=== backing up the working kernel on the board ==="
ssh $O root@$B 'cp -n /boot/zImage /boot/zImage.prev 2>/dev/null
  cp -n /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.prev 2>/dev/null
  echo "  zImage.prev: $(md5sum /boot/zImage.prev 2>/dev/null | cut -d" " -f1)"' 2>&1 | grep -vi warning || true

scp $O $I/zImage root@$B:/boot/zImage.new 2>&1 | grep -vi warning || true
scp $O "$R/boot/extlinux/extlinux.conf" root@$B:/boot/extlinux/extlinux.conf.new 2>&1 | grep -vi warning || true

ssh $O root@$B 'set -e
  sed -i "s/\r$//" /boot/extlinux/extlinux.conf.new
  # sanity-check the new config before committing to it
  grep -q "^    kernel /boot/zImage" /boot/extlinux/extlinux.conf.new
  grep -q "fbcon=rotate:2" /boot/extlinux/extlinux.conf.new
  grep -q "root=/dev/mmcblk0p1" /boot/extlinux/extlinux.conf.new
  mv /boot/zImage.new /boot/zImage
  mv /boot/extlinux/extlinux.conf.new /boot/extlinux/extlinux.conf
  sync
  echo "--- installed ---"
  echo "zImage md5 : $(md5sum /boot/zImage | cut -d" " -f1)"
  echo "cmdline    : $(grep "^    append" /boot/extlinux/extlinux.conf)"
  echo "fallback   : /boot/zImage.prev + extlinux.conf.prev present"' 2>&1 | grep -vi warning || true

echo "=== expected (host) ==="
echo "zImage md5 : $(md5sum $I/zImage | cut -d' ' -f1)"
