#!/bin/sh
for t in a b c d; do
  f=/tmp/glitch_$t.log
  [ -f "$f" ] || continue
  echo "=== $f ==="
  echo "  lines: $(wc -l < $f)"
  echo "  first SEC : $(grep '^SEC' $f | head -1)"
  echo "  last SEC  : $(grep '^SEC' $f | tail -1)"
  echo "  maxjump distribution (is the detector seeing real audio?):"
  grep '^SEC' $f | sed -n 's/.*maxjump=\([0-9]*\).*/    \1/p' | sort -n | uniq -c | tail -6
done
