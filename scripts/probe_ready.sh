#!/bin/sh
C=/usr/lib/libretro/paralleln64_libretro.so
echo "speed probe in core : $(strings $C | grep -c 'speed_permille')"
rm -f /tmp/glitch.log
echo "log cleared"
echo
echo "=== spreading interrupts off a single core ==="
echo "before:"
head -1 /proc/interrupts
grep -E 'ttyS1| gp$| pp0| pp1|lcd-controller|dma-controller' /proc/interrupts
# 141 = bluetooth UART, 35/36/37 = Mali GPU, 142 = LCD, 30 = audio DMA
# Give the GPU and BT their own cores so they do not all pile onto CPU0.
echo 2 > /proc/irq/141/smp_affinity 2>/dev/null   # BT UART  -> CPU1
echo 4 > /proc/irq/35/smp_affinity  2>/dev/null   # Mali gp  -> CPU2
echo 4 > /proc/irq/36/smp_affinity  2>/dev/null   # Mali pp0 -> CPU2
echo 4 > /proc/irq/37/smp_affinity  2>/dev/null   # Mali pp1 -> CPU2
echo 1 > /proc/irq/30/smp_affinity  2>/dev/null   # audio DMA stays CPU0
echo 1 > /proc/irq/142/smp_affinity 2>/dev/null   # LCD stays CPU0
echo "requested affinities:"
for i in 30 35 36 37 141 142; do
  echo "  irq $i -> cpus $(cat /proc/irq/$i/smp_affinity_list 2>/dev/null)"
done
