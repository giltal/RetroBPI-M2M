#!/bin/sh
L=/tmp/glitch.log
[ -f "$L" ] || { echo "no log"; exit 1; }
echo "=== seconds recorded: $(grep -c '^SEC' $L) ==="
echo
echo "=== CLIPPING: seconds with clipped samples (worst first) ==="
grep '^SEC' $L | sed -n 's/.*t=\([0-9]*\).*peak=\([0-9]*\).*clip=\([0-9]*\).*/\3 t=\1 peak=\2 clip=\3/p' \
  | sort -rn | head -15 | sed 's/^[0-9]* //;s/^/  /'
echo
echo "  total clipped samples : $(grep '^SEC' $L | sed -n 's/.*clip=\([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
echo "  seconds with any clip : $(grep '^SEC' $L | sed -n 's/.*clip=\([0-9]*\).*/\1/p' | awk '$1>0' | wc -l)"
echo
echo "=== PEAK level distribution (32767 = full scale) ==="
grep '^SEC' $L | sed -n 's/.*peak=\([0-9]*\).*/\1/p' | sort -n | uniq -c | tail -10 | sed 's/^/  /'
echo
echo "=== silence gaps (>10ms of near-silence) ==="
echo "  total: $(grep '^SEC' $L | sed -n 's/.*sil=\([0-9]*\).*/\1/p' | tail -1)"
echo
echo "=== jumps (clicks) ==="
echo "  total: $(grep '^SEC' $L | sed -n 's/.*jump=\([0-9]*\).*/\1/p' | awk '{s+=$1} END{print s+0}')"
echo
echo "=== last 25 seconds, full detail ==="
grep '^SEC' $L | tail -25
