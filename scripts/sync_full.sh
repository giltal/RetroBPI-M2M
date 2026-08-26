#!/bin/bash
# Full image -> board sync: push every file whose content differs from the
# built target/ tree.
#
# EXCLUSIONS, all deliberate:
#   /var/lib/bluetooth  - holds the live DS3 link key. Overwriting it with the
#                         image's empty copy would silently unpair the pad.
#   /var/log, /var/run  - runtime state, not image content.
#   /opt/roms           - separate vfat partition, gigabytes, not in target/.
#   /etc/ssh            - host keys are generated per-board on first boot.
set -e
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
T=/home/giltal/bpi/output/target
ROOTS="usr/bin usr/sbin usr/lib usr/share/retroarch usr/share/libretro etc root boot"

RA=$(ssh $O root@$B 'ps w | grep [r]etroarch | wc -l' 2>/dev/null | tr -d '[:space:]')
[ "$RA" = "0" ] || { echo "ABORT: retroarch running on the board"; exit 2; }

echo "=== hashing host target/ ==="
wsl bash -c "cd $T && find $ROOTS -type f -print0 2>/dev/null | xargs -0 md5sum 2>/dev/null | sort -k2" > /tmp/host.md5
echo "  $(wc -l < /tmp/host.md5) files"

echo "=== hashing board ==="
ssh $O root@$B "cd / && find $ROOTS -type f -print0 2>/dev/null | xargs -0 md5sum 2>/dev/null | sort -k2" 2>/dev/null > /tmp/board.md5
echo "  $(wc -l < /tmp/board.md5) files"

echo "=== differences ==="
# join on filename; report content mismatches and host-only files
awk 'NR==FNR{h[substr($0,35)]=substr($0,1,32);next}
     {b[substr($0,35)]=substr($0,1,32)}
     END{
       for(f in h){ if(!(f in b)) print "MISSING\t"f; else if(h[f]!=b[f]) print "DIFFER\t"f }
       for(f in b){ if(!(f in h)) print "EXTRA\t"f }
     }' /tmp/host.md5 /tmp/board.md5 | sort > /tmp/diff.txt
grep -c . /tmp/diff.txt || true
head -40 /tmp/diff.txt
echo "..."
echo "MISSING: $(grep -c '^MISSING' /tmp/diff.txt || true)  DIFFER: $(grep -c '^DIFFER' /tmp/diff.txt || true)  EXTRA(board-only): $(grep -c '^EXTRA' /tmp/diff.txt || true)"
