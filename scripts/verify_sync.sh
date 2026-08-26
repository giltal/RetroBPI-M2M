#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
T=~/bpi/output/target
I=~/bpi/output/images
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/board_md5.sh root@$B:/tmp/bm.sh 2>&1 | grep -vi warning || true
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/bm.sh; sh /tmp/bm.sh" 2>&1 | grep -vi warning > /tmp/board.txt || true

# host list: "md5 basename-or-path"
{
  for f in usr/bin/retrobpi_launcher usr/bin/retroarch root/.config/retroarch/retroarch.cfg \
           etc/init.d/S05powercap etc/init.d/S12launcher etc/init.d/S35alsa ; do
    [ -e "$T/$f" ] && echo "$(md5sum "$T/$f" | cut -d' ' -f1) /$f"
  done
  for so in $T/usr/lib/libretro/*.so; do
    echo "$(md5sum "$so" | cut -d' ' -f1) $(basename $so)"
  done
} | sort -k2 > /tmp/host.txt

# board list, same shape
{
  grep -E '^[0-9a-f]{32}  /(usr|root|etc)' /tmp/board.txt | awk '{print $1" "$2}'
  awk '/^[0-9a-f]{32}  [a-z0-9_]+_libretro\.so$/{print $1" "$2}' /tmp/board.txt
} | sort -k2 > /tmp/brd.txt

echo "host entries: $(wc -l < /tmp/host.txt)   board entries: $(wc -l < /tmp/brd.txt)"
echo
echo "=== diff (host vs board) ==="
if diff -u /tmp/host.txt /tmp/brd.txt > /tmp/d.txt; then
  echo "IDENTICAL - board matches the built image on every file checked"
else
  cat /tmp/d.txt | grep -E '^[-+][0-9a-f]' || cat /tmp/d.txt
fi
echo
echo "=== kernel / dtb ==="
echo "zImage board=$(grep '/boot/zImage' /tmp/board.txt | cut -d' ' -f1)  host=$(md5sum $I/zImage 2>/dev/null | cut -d' ' -f1)"
echo "dtb    board=$(grep '/boot/sun8i' /tmp/board.txt | cut -d' ' -f1)  host=$(md5sum $I/sun8i-a33-bananapi-m2m-ws5b.dtb 2>/dev/null | cut -d' ' -f1)"
