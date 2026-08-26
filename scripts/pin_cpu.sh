#!/bin/sh
# Move the emulator off CPU0, which serves every interrupt on this board.
MASK=${1:-c}     # default 0xc = CPU2+CPU3
P=$(ps w | grep retroarch.bin | grep -v grep | awk '{print $1}' | head -1)
[ -z "$P" ] && { echo "no game running"; exit 1; }
echo "pid $P"
echo "before:"
for t in /proc/$P/task/*; do
  tid=$(basename $t)
  echo "  tid $tid affinity=$(taskset -p $tid 2>/dev/null | sed 's/.*: //') cpu=$(awk '{print $39}' $t/stat)"
done
for t in /proc/$P/task/*; do
  taskset -p $MASK $(basename $t) >/dev/null 2>&1
done
sleep 3
echo "after (mask 0x$MASK):"
for t in /proc/$P/task/*; do
  tid=$(basename $t)
  echo "  tid $tid affinity=$(taskset -p $tid 2>/dev/null | sed 's/.*: //') cpu=$(awk '{print $39}' $t/stat)"
done
