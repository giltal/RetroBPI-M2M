#!/bin/sh
L=/tmp/glitch.log
[ -f "$L" ] || { echo "no log"; exit 1; }
N=$(grep -c '^SEC' $L)
echo "seconds recorded: $N"
[ "$N" -eq 0 ] && { echo "no SEC lines"; exit 1; }
echo
echo "=== EMULATION SPEED (1000 = exactly real time) ==="
echo "  worst 12 seconds:"
grep '^SEC' $L | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | sort -n | head -12 | sed 's/^/    /'
echo "  best 5:"
grep '^SEC' $L | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | sort -n | tail -5 | sed 's/^/    /'
echo
S=$(grep '^SEC' $L | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | awk '{s+=$1; n++} END{if(n)print int(s/n); else print 0}')
echo "  AVERAGE speed_permille : $S"
echo "  seconds below 980      : $(grep '^SEC' $L | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | awk '$1<980' | wc -l) of $N"
echo "  seconds below 950      : $(grep '^SEC' $L | sed -n 's/.*speed_permille=\([0-9]*\).*/\1/p' | awk '$1<950' | wc -l) of $N"
echo
echo "=== overall audio vs wall clock (the definitive ratio) ==="
grep '^SEC' $L | tail -1
A=$(grep '^SEC' $L | tail -1 | sed -n 's/.*audio=\([0-9.]*\).*/\1/p')
W=$(grep '^SEC' $L | tail -1 | sed -n 's/.*wall=\([0-9.]*\).*/\1/p')
echo "  audio produced: ${A}s over ${W}s of wall clock"
echo "$A $W" | awk '{if($2>0) printf "  ratio: %.4f  (1.0 = keeping up perfectly)\n", $1/$2}'
echo
echo "=== clipping (should still be zero) ==="
echo "  total: $(grep '^SEC' $L | sed -n 's/.*clip=\([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
echo
echo "=== last 20 seconds ==="
grep '^SEC' $L | tail -20
echo
echo "=== did the IRQ spreading take effect? ==="
head -1 /proc/interrupts
grep -E 'ttyS1| gp$| pp0| pp1|lcd-controller|dma-controller' /proc/interrupts
