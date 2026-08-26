#!/bin/sh
# Start a detached capture. Collect later with l3_collect.sh.
DEV=/dev/input/event3
for p in $(ps w | grep '[e]vtest' | awk '{print $1}'); do kill -9 $p 2>/dev/null; done
rm -f /tmp/l3.log
setsid nohup evtest "$DEV" > /tmp/l3.log 2>&1 &
sleep 2
echo "evtest running : $(ps w | grep -c '[e]vtest')"
echo "log so far     : $(wc -c < /tmp/l3.log) bytes (header only until you press something)"
echo
echo "=== is anything holding the device exclusively (EVIOCGRAB)? ==="
echo "launcher running: $(ps w | grep -c '[r]etrobpi_launcher')"
for f in /proc/*/fd/*; do
  tgt=$(readlink "$f" 2>/dev/null)
  case "$tgt" in
    /dev/input/event3)
      pid=$(echo "$f" | cut -d/ -f3)
      echo "  event3 held by pid $pid ($(cat /proc/$pid/comm 2>/dev/null))"
      ;;
  esac
done
