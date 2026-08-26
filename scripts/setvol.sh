#!/bin/sh
# DATA_DIR in launcher.c is "/opt/roms/_system" -- state.txt lives there.
D=/opt/roms/_system
S=$D/state.txt
if ps w | grep -q "[r]etroarch.bin"; then echo "REFUSING: game running"; exit 2; fi
rm -rf /opt/roms/_data 2>/dev/null   # stray dir from a wrong guess earlier
echo "=== $S before ==="
[ -f "$S" ] && cat "$S" || echo "  (does not exist yet)"
mkdir -p "$D"
if [ -f "$S" ] && grep -q '^volume=' "$S"; then
  sed -i 's/^volume=.*/volume=100/' "$S"
else
  echo "volume=100" >> "$S"
fi
echo "=== after ==="
cat "$S"
/etc/init.d/S12launcher stop >/dev/null 2>&1; sleep 2
/etc/init.d/S12launcher start >/dev/null 2>&1; sleep 4
echo "=== mixer now ==="
amixer -c 0 cget name='Headphone Playback Volume' 2>/dev/null | grep ': values'
echo "  63 = full analog (0 dB). 45 was 55% on the dial, so this is +18 dB."
echo "=== launcher running: $(ps w | grep retrobpi_launcher | grep -v grep | wc -l) ==="
