#!/bin/sh
L=/tmp/glitch.log
[ -f "$L" ] || { echo "no log"; exit 1; }
echo "seconds recorded: $(grep -c '^SEC' $L)"
echo "gain in use     : $(grep -m1 '^SEC' $L | sed -n 's/.*gain=\([0-9]*\).*/\1/p') permille"
echo
echo "=== CLIPPING after the headroom fix ==="
echo "  total clipped samples : $(grep '^SEC' $L | sed -n 's/.* clip=\([0-9]*\) .*/\1/p' | awk '{s+=$1} END{print s+0}')"
echo "  seconds with any clip : $(grep '^SEC' $L | sed -n 's/.* clip=\([0-9]*\) .*/\1/p' | awk '$1>0' | wc -l)"
echo "  worst seconds:"
grep '^SEC' $L | sed -n 's/.*t=\([0-9]*\) s16peak=\([0-9]*\) clip=\([0-9]*\) float_permille=\([0-9]*\).*/\3 t=\1 s16peak=\2 clip=\3 float=\4/p' \
  | sort -rn | head -8 | sed 's/^[0-9]* /    /'
echo
echo "=== FLOAT PEAK: how far past full scale the resampler actually goes ==="
echo "  (1000 = exactly 0 dBFS at the CURRENT 0.8 gain; >1000 means still clipping)"
grep '^SEC' $L | sed -n 's/.*float_permille=\([0-9]*\).*/\1/p' | sort -n | tail -12 | sed 's/^/    /'
echo
echo "=== s16 peak distribution (32767 = clamped) ==="
grep '^SEC' $L | sed -n 's/.*s16peak=\([0-9]*\).*/\1/p' | sort -n | tail -8 | sed 's/^/    /'
echo
echo "=== last 20 seconds ==="
grep '^SEC' $L | tail -20
