#!/bin/sh
P=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/post-build.sh
rm -rf /tmp/gt; mkdir -p /tmp/gt/usr/lib/libretro /tmp/gt/etc/init.d /tmp/gt/root/.config/retroarch/config
touch /tmp/gt/etc/init.d/S12launcher
printf 'audio_driver = "alsathread"\n' > /tmp/gt/root/.config/retroarch/retroarch.cfg

echo "=== CASE 1: a core containing instrumentation (must FAIL) ==="
printf 'padding astick.log padding' > /tmp/gt/usr/lib/libretro/fake_libretro.so
sh "$P" /tmp/gt >/tmp/g1.out 2>&1
echo "  exit code: $?  (expect 1)"
grep -i 'ERROR' /tmp/g1.out | sed 's/^/  /'

echo
echo "=== CASE 2: clean cores (must PASS) ==="
printf 'ordinary core with no probes' > /tmp/gt/usr/lib/libretro/fake_libretro.so
sh "$P" /tmp/gt >/tmp/g2.out 2>&1
echo "  exit code: $?  (expect 0)"
tail -1 /tmp/g2.out | sed 's/^/  /'
rm -rf /tmp/gt
