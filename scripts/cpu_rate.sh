#!/bin/sh
# READ-ONLY: measure actual CPU utilisation per thread over a 10 s window.
P=$(ps w | grep retroarch.bin | grep -v grep | awk '{print $1}' | head -1)
[ -z "$P" ] && { echo "no game running"; exit 1; }
W=10
echo "sampling pid $P for ${W}s..."
for t in /proc/$P/task/*; do
  tid=$(basename $t)
  echo "$tid $(awk '{print $14+$15}' $t/stat 2>/dev/null)" >> /tmp/t0.txt
done
I0=$(awk '/1c02000.dma-controller/{print $2}' /proc/interrupts)
V0=$(awk '/1c0c000.lcd-controller/{print $2}' /proc/interrupts)
sleep $W
echo "--- per-thread CPU over ${W}s (100 ticks = 1 s of CPU) ---"
for t in /proc/$P/task/*; do
  tid=$(basename $t)
  nm=$(cat $t/comm 2>/dev/null)
  now=$(awk '{print $14+$15}' $t/stat 2>/dev/null)
  was=$(grep "^$tid " /tmp/t0.txt | awk '{print $2}')
  [ -z "$was" ] && was=0
  d=$((now - was))
  pct=$((d * 100 / (W * 100)))
  cpu=$(awk '{print $39}' $t/stat 2>/dev/null)
  [ "$d" -gt 0 ] && echo "  $nm (tid $tid): ${pct}% of one core  [running on cpu$cpu]"
done
rm -f /tmp/t0.txt
I1=$(awk '/1c02000.dma-controller/{print $2}' /proc/interrupts)
V1=$(awk '/1c0c000.lcd-controller/{print $2}' /proc/interrupts)
echo "--- rates ---"
echo "  audio DMA irq : $(( (I1-I0) / W )) /s"
echo "  lcd irq       : $(( (V1-V0) / W )) /s  (~60 = display keeping up)"
echo "--- overall ---"
top -b -n2 -d3 2>/dev/null | grep -E '^CPU|^Mem' | tail -2
