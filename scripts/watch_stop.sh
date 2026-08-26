#!/bin/sh
echo "=== watchers before ==="
ps w | grep 'aw\.sh' | grep -v grep
for p in $(ps w | grep 'aw\.sh' | grep -v grep | awk '{print $1}'); do
  kill $p 2>/dev/null
done
sleep 2
for p in $(ps w | grep 'aw\.sh' | grep -v grep | awk '{print $1}'); do
  kill -9 $p 2>/dev/null
done
sleep 1
echo "=== watchers after ==="
n=$(ps w | grep 'aw\.sh' | grep -v grep | wc -l)
echo "remaining: $n"
echo "=== preserved session 1 (the real capture) ==="
cat /tmp/gameplay_session1.log 2>/dev/null
echo "=== state ==="
echo "launcher: $(ps w | grep 'retrobpi_launcher' | grep -v grep | wc -l)  retroarch: $(ps w | grep 'retroarch.bin' | grep -v grep | wc -l)"
