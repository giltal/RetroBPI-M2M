#!/bin/sh
L=/tmp/gameplay.log
NOW=$(cut -d. -f1 /proc/uptime)
echo "=== uptime now: ${NOW}s  (you reported the break just now) ==="
echo "total lines: $(wc -l < $L)"
echo
echo "=== FULL UNDERRUNS (stream reset - unambiguous) ==="
grep RESET $L || echo "  none"
echo
echo "=== margin dips below 64ms ==="
grep -vE '^#| MIN |RESET' $L | tail -20 || true
echo "  count: $(grep -vcE '^#| MIN |RESET' $L)"
echo
echo "=== margin trend, last 45 seconds (per-second minimum) ==="
grep ' MIN ' $L | tail -45
echo
echo "=== worst seconds in the whole run ==="
grep ' MIN ' $L | sort -k3 -n | head -12
echo
echo "=== game / watcher ==="
echo "retroarch: $(ps w | grep 'retroarch.bin' | grep -v grep | wc -l)  watcher: $(ps w | grep 'aw\.sh' | grep -v grep | wc -l)"
