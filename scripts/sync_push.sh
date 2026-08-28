#!/bin/bash
# Push every file that differs between the built image and the board.
#
# EXCLUSIONS (deliberate, not oversights):
#   etc/passwd, etc/shadow, etc/group
#       The BOARD has a dbus user that the IMAGE does not, so overwriting these
#       would delete it and can break dbus on the next boot. The shadow hashes
#       differ only by salt -- same password -- so there is nothing to gain
#       either. This is a real discrepancy in the image worth fixing at source,
#       not something to paper over by pushing.
#   etc/udev/hwdb.d/*
#       28 files, several MB, and inert: udev reads the compiled hwdb.bin, which
#       neither side has. Pushing them costs rootfs space and buys nothing, and
#       the boot is I/O-bound.
#   var/lib/bluetooth, opt/roms, root/.config/retroarch/saves
#       Live state: the DS3 link key, the ROM partition, and the user's saves.
set -e
B=${BOARD:-10.100.102.76}
O="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15"
T=/home/giltal/bpi/output/target
# Shared scratch: git-bash and WSL disagree about /tmp, and a list written in
# one and read in the other comes back empty -- tar then pushes nothing while
# appearing to succeed.
SHARE=/mnt/c/BananaPi_Projects/RetroBPI_M2M/.syncscratch
WSHARE="C:/BananaPi_Projects/RetroBPI_M2M/.syncscratch"
mkdir -p "$WSHARE"
ROOTS="usr/bin usr/sbin usr/lib usr/share/retroarch etc root boot"

RA=$(ssh $O root@$B 'ps w | grep -c "[r]etroarch"' 2>/dev/null | tr -d '[:space:]')
[ "$RA" = "0" ] || { echo "ABORT: retroarch running on the board"; exit 2; }

wsl bash -c "cd $T && find $ROOTS -type f -print0 2>/dev/null | xargs -0 md5sum 2>/dev/null | sort -k2" > "$WSHARE/h.md5"
ssh $O root@$B "cd / && find $ROOTS -type f -print0 2>/dev/null | xargs -0 md5sum 2>/dev/null | sort -k2" 2>/dev/null > "$WSHARE/b.md5"

awk 'NR==FNR{h[substr($0,35)]=substr($0,1,32);next}
     {b[substr($0,35)]=substr($0,1,32)}
     END{for(f in h) if(!(f in b) || h[f]!=b[f]) print f}' "$WSHARE/h.md5" "$WSHARE/b.md5" \
 | grep -vE '^etc/(passwd|shadow|group)$' \
 | grep -vE '^etc/udev/hwdb\.d/' \
 | sort > "$WSHARE/push.list"

echo "=== files to push: $(wc -l < "$WSHARE/push.list") ==="
cat "$WSHARE/push.list" | sed 's/^/  /'
[ -s "$WSHARE/push.list" ] || { echo "nothing to do"; exit 0; }

echo "=== backing up the board's current copies ==="
ssh $O root@$B "cd / && tar cf - -T -" < "$WSHARE/push.list" 2>/dev/null \
  | gzip > backup/board-preSync-$(date +%Y%m%d-%H%M).tar.gz || true
ls -la backup/ | tail -2

echo "=== pushing ==="
wsl bash -c "cd $T && tar cf - -T $SHARE/push.list" | ssh $O root@$B 'tar xf - -C / && echo "extracted"'

echo "=== verify ==="
# NOT xargs: several RetroArch config paths contain spaces ("ParaLLEl N64"),
# and xargs splits on whitespace -- md5sum then fails on both halves and the
# check reports a MISMATCH for files that were pushed perfectly well. Feed
# the list to a shell loop that reads whole lines instead.
ssh $O root@$B 'cd / && while IFS= read -r f; do [ -n "$f" ] && md5sum "$f"; done' < "$WSHARE/push.list" 2>/dev/null | sort -k2 > "$WSHARE/b2.md5"
n=0; bad=0
while read f; do
  a=$(grep -F " $f" "$WSHARE/h.md5"  | head -1 | cut -c1-32)
  c=$(grep -F " $f" "$WSHARE/b2.md5" | head -1 | cut -c1-32)
  n=$((n+1)); [ "$a" = "$c" ] || { echo "  MISMATCH: $f"; bad=$((bad+1)); }
done < "$WSHARE/push.list"
echo "  $((n-bad))/$n files now match the image"
