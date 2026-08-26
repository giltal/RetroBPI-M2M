#!/bin/sh
echo "=== log size: $(wc -c < /tmp/l3.log 2>/dev/null) bytes ==="
echo
echo "=== ACTUAL events (lines beginning 'Event:') ==="
grep '^Event:' /tmp/l3.log 2>/dev/null | grep 'EV_KEY' | sed 's/^/  /' | head -25
echo "  total real key events: $(grep -c '^Event:.*EV_KEY' /tmp/l3.log 2>/dev/null)"
echo
echo "=== distinct buttons actually pressed ==="
grep '^Event:.*EV_KEY' /tmp/l3.log 2>/dev/null | sed -n 's/.*(\(BTN_[A-Z0-9_]*\)).*/\1/p' | sort | uniq -c | sed 's/^/  /'
for p in $(ps w | grep '[e]vtest' | awk '{print $1}'); do kill -9 $p 2>/dev/null; done
echo "(capture stopped)"
