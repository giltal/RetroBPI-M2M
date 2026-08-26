#!/bin/sh
# No 'timeout' on this busybox -- background the reader and kill it instead.
DEV=/dev/input/event3
rm -f /tmp/l3.log
evtest "$DEV" > /tmp/l3.log 2>&1 &
P=$!
sleep 2
if ! kill -0 $P 2>/dev/null; then
  echo "evtest exited immediately:"; cat /tmp/l3.log; exit 1
fi
echo "CAPTURING for 30 s on $DEV"
echo "  press L3 (left stick click) x3, then R3 x3, then X or O as a reference"
sleep 30
kill -INT $P 2>/dev/null; sleep 1; kill $P 2>/dev/null; sleep 1
echo
echo "=== log size: $(wc -c < /tmp/l3.log) bytes ==="
echo
echo "=== every distinct button seen ==="
grep 'EV_KEY' /tmp/l3.log | sed -n 's/.*code \([0-9]*\) (\([A-Z_0-9]*\)).*/\1 \2/p' | sort -u | sed 's/^/  /'
echo
echo "=== counts ==="
printf '  THUMBL (L3, 317) : %s\n' "$(grep -c 'BTN_THUMBL' /tmp/l3.log)"
printf '  THUMBR (R3, 318) : %s\n' "$(grep -c 'BTN_THUMBR' /tmp/l3.log)"
printf '  total EV_KEY     : %s\n' "$(grep -c 'EV_KEY' /tmp/l3.log)"
echo
echo "=== first few events ==="
grep 'EV_KEY' /tmp/l3.log | head -8 | sed 's/^/  /'
