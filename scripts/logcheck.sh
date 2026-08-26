#!/bin/sh
L=/tmp/gameplay.log
echo "total lines: $(wc -l < $L)"
echo "=== line types ==="
echo "  MIN     : $(grep -c ' MIN ' $L)"
echo "  REARM   : $(grep -c REARM $L)"
echo "  NEWWORST: $(grep -c NEWWORST $L)"
echo "  RESET   : $(grep -c RESET $L)"
echo "  other   : $(grep -vcE ' MIN |REARM|NEWWORST|RESET|^#' $L)"
echo "=== sample of the dominant type ==="
grep -E 'REARM' $L | head -5
echo "=== last 8 lines ==="
tail -8 $L
