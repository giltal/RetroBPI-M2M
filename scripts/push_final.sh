#!/bin/bash
# Push the shipping build to the board: clean core + configs, no instrumentation.
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
T=~/bpi/output/target
R=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/rootfs_overlay

RA=$(ssh $O root@$B 'ps w | grep retroarch.bin | grep -v grep | wc -l' 2>/dev/null | tr -d '[:space:]')
if [ "$RA" != "0" ]; then echo "ABORT: a game is running on the board"; exit 2; fi
echo "no game running - safe to push"

# refuse to push an instrumented core
if strings $T/usr/lib/libretro/paralleln64_libretro.so | grep -q 'glitch.log\|speed_permille'; then
  echo "ABORT: build tree core still contains instrumentation"; exit 3
fi
echo "core verified clean"

scp $O $T/usr/lib/libretro/paralleln64_libretro.so root@$B:/tmp/new_n64.so 2>&1 | grep -vi warning || true
scp $O "$R/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt" \
       "root@$B:'/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt'" 2>&1 | grep -vi warning || true
scp $O "$R/root/.config/retroarch/retroarch.cfg" root@$B:/root/.config/retroarch/retroarch.cfg 2>&1 | grep -vi warning || true
scp $O "$R/etc/init.d/S05powercap" root@$B:/etc/init.d/S05powercap 2>&1 | grep -vi warning || true

ssh $O root@$B "sed -i 's/\r\$//' /etc/init.d/S05powercap; chmod +x /etc/init.d/S05powercap
  cp /tmp/new_n64.so /usr/lib/libretro/paralleln64_libretro.so
  rm -f /tmp/new_n64.so /tmp/n64_stock.so /tmp/n64dbg.so /tmp/glitch.log /tmp/audio_dump.raw /tmp/dump_on
  echo '--- verification ---'
  echo \"instrumentation on board : \$(strings /usr/lib/libretro/paralleln64_libretro.so | grep -c 'glitch.log\|speed_permille')  (must be 0)\"
  echo \"screensize               : \$(grep -h '^parallel-n64-screensize' '/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt')\"
  echo \"gfxplugin                : \$(grep -h '^parallel-n64-gfxplugin ' '/root/.config/retroarch/config/ParaLLEl N64/ParaLLEl N64.opt')\"
  echo \"audio_driver             : \$(grep -h '^audio_driver' /root/.config/retroarch/retroarch.cfg)\"
  echo \"audio_latency            : \$(grep -h '^audio_latency' /root/.config/retroarch/retroarch.cfg)\"
  echo \"governor                 : \$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)\"
  echo \"launcher                 : \$(ps w | grep retrobpi_launcher | grep -v grep | wc -l) proc\"" 2>&1 | grep -vi warning || true

echo "=== md5 comparison (board vs build) ==="
BM=$(ssh $O root@$B 'md5sum /usr/lib/libretro/paralleln64_libretro.so' 2>/dev/null | cut -d' ' -f1)
HM=$(md5sum $T/usr/lib/libretro/paralleln64_libretro.so | cut -d' ' -f1)
echo "  board: $BM"
echo "  build: $HM"
[ "$BM" = "$HM" ] && echo "  MATCH" || echo "  MISMATCH"
