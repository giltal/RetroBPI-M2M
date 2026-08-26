#!/bin/sh
# READ-ONLY. Where are the cycles going during a race?
echo "=== per-thread CPU of the running emulator ==="
P=$(ps w | grep retroarch.bin | grep -v grep | awk '{print $1}' | head -1)
if [ -z "$P" ]; then echo "  (no game running - start one first)"; else
  echo "  pid $P, threads:"
  for t in /proc/$P/task/*; do
    tid=$(basename $t)
    nm=$(cat $t/comm 2>/dev/null)
    st=$(awk '{print $14+$15}' $t/stat 2>/dev/null)
    cpu=$(awk '{print $39}' $t/stat 2>/dev/null)
    echo "    tid=$tid $nm ticks=$st last_cpu=$cpu"
  done
fi
echo
echo "=== IRQ distribution across cores (ttyS1 = Bluetooth UART) ==="
head -1 /proc/interrupts
grep -E 'ttyS1|dma-controller|lcd-controller| gp$| pp0| pp1' /proc/interrupts
echo
echo "=== irq affinity (which core serves the BT UART) ==="
for i in 141 30 142; do
  echo "  irq $i affinity: $(cat /proc/irq/$i/smp_affinity_list 2>/dev/null)"
done
echo
echo "=== load ==="
uptime
