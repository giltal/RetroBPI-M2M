#!/bin/bash
SRC=~/bpi/output/build/retrobpi-launcher-local
echo "=== new code present in the build tree? ==="
echo -n "  menu_jump_letter occurrences: "
grep -c 'menu_jump_letter' "$SRC/launcher.c"
echo -n "  NUL bytes in source (want 0): "
grep -c $'\x00' "$SRC/launcher.c" 2>/dev/null || echo 0
echo
echo "=== timestamps ==="
ls -l --time-style=+%H:%M:%S "$SRC/launcher.c" "$SRC/launcher.o" "$SRC/retrobpi_launcher" 2>/dev/null | awk '{print "  "$6"  "$7}'
echo
echo "=== object size ==="
stat -c '  launcher.o: %s bytes' "$SRC/launcher.o" 2>/dev/null || ls -l "$SRC/launcher.o" | awk '{print "  launcher.o: "$5" bytes"}'
