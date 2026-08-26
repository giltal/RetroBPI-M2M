#!/bin/bash
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
T=~/bpi/output/target
scp $O /mnt/c/BananaPi_Projects/RetroBPI_M2M/scripts/board_md5.sh root@$B:/tmp/bm.sh 2>&1 | grep -vi warning
ssh $O root@$B "sed -i \"s/\r\$//\" /tmp/bm.sh; sh /tmp/bm.sh" 2>&1 | grep -vi warning > /tmp/board.txt
echo "=== host image tree equivalents ==="
for f in usr/bin/retrobpi_launcher usr/bin/retroarch root/.config/retroarch/retroarch.cfg \
         etc/init.d/S05powercap etc/init.d/S12launcher etc/init.d/S35alsa ; do
  if [ -e "$T/$f" ]; then echo "$(md5sum "$T/$f" | cut -d' ' -f1)  /$f"; else echo "MISSING  /$f"; fi
done
echo "--- cores (host) ---"
md5sum $T/usr/lib/libretro/*.so 2>/dev/null | sed "s|$T/usr/lib/libretro/||" | sort -k2 > /tmp/host_cores.txt
wc -l < /tmp/host_cores.txt | sed 's/^/count: /'
echo
echo "=== BOARD ==="
cat /tmp/board.txt
