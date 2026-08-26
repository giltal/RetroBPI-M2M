#!/bin/sh
echo "=== did the previous run write anything at all? ==="
ls -la /tmp/l3.log 2>/dev/null
echo "  bytes: $(wc -c < /tmp/l3.log 2>/dev/null)"
echo "--- head ---"
head -12 /tmp/l3.log 2>/dev/null
echo
echo "=== buffering helpers available? ==="
for t in stdbuf script unbuffer; do printf '  %-8s %s\n' "$t" "$(command -v $t || echo missing)"; done
echo
echo "=== quick unbuffered smoke test: 5 s, cat the raw device ==="
echo "  (any controller activity should produce bytes)"
timeout 5 cat /dev/input/event3 > /tmp/raw.bin 2>/dev/null
echo "  raw bytes captured: $(wc -c < /tmp/raw.bin 2>/dev/null)"
