#!/bin/bash
set -e
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
T=~/bpi/output/target

# SAFETY: never yank the launcher out from under a running game.
RA=$(ssh $O root@$B 'ps w | grep retroarch | grep -v grep | wc -l' 2>/dev/null | tr -d "[:space:]")
if [ "$RA" != "0" ]; then
  echo "ABORT: retroarch is running on the board ($RA proc). Not touching it."
  exit 2
fi
echo "no game running - safe to sync"

scp $O "$T/usr/bin/retrobpi_launcher"                 root@$B:/tmp/new_launcher 2>&1 | grep -vi warning || true
scp $O "$T/usr/lib/libretro/pcsx_rearmed_libretro.so" root@$B:/tmp/new_pcsx.so  2>&1 | grep -vi warning || true

ssh $O root@$B '
  /etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
  cp /tmp/new_launcher /usr/bin/retrobpi_launcher && chmod +x /usr/bin/retrobpi_launcher
  cp /tmp/new_pcsx.so /usr/lib/libretro/pcsx_rearmed_libretro.so
  rm -f /tmp/new_launcher /tmp/new_pcsx.so
  /etc/init.d/S12launcher start >/dev/null 2>&1; sleep 2
  echo "launcher running: $(ps w | grep retrobpi_launcher | grep -v grep | wc -l)"
  echo "launcher md5    : $(md5sum /usr/bin/retrobpi_launcher | cut -d" " -f1)"
  echo "pcsx md5        : $(md5sum /usr/lib/libretro/pcsx_rearmed_libretro.so | cut -d" " -f1)"
' 2>&1 | grep -vi warning || true

echo "=== expected (host) ==="
echo "launcher md5    : $(md5sum $T/usr/bin/retrobpi_launcher | cut -d' ' -f1)"
echo "pcsx md5        : $(md5sum $T/usr/lib/libretro/pcsx_rearmed_libretro.so | cut -d' ' -f1)"
