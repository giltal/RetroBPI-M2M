#!/bin/bash
SRC=~/bpi/output/build/retrobpi-launcher-local
BIN=~/bpi/output/target/usr/bin/retrobpi_launcher
echo "=== new code in the synced source? ==="
echo -n "  ui_draw_jump_hint : "; grep -c 'ui_draw_jump_hint' "$SRC/launcher.c"
echo -n "  FONT_SIZE_JUMP    : "; grep -c 'FONT_SIZE_JUMP' "$SRC/launcher.c"
echo
echo "=== object rebuilt after the source changed? ==="
ls -l --time-style=+%H:%M:%S "$SRC/launcher.c" "$SRC/launcher.o" "$BIN" | awk '{print "  "$6"  "$NF}'
echo
echo "=== sizes ==="
echo "  launcher.o : $(wc -c < "$SRC/launcher.o") bytes"
echo "  binary     : $(wc -c < "$BIN") bytes"
echo "  binary md5 : $(md5sum "$BIN" | cut -d' ' -f1)"
echo
echo "=== does the binary differ from the one currently on the board? ==="
echo "  (compare this md5 with the board's after pushing)"
