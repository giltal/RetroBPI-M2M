#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/retroarch-* | head -1)
echo "=== where input_remapping functions are implemented ==="
grep -rln 'input_remapping_load_file\|input_remapping_save_file' "$D" --include=*.c 2>/dev/null | head -4
echo
F=$(grep -rln 'input_remapping_load_file' "$D" --include=*.c 2>/dev/null | head -1)
echo "file: $F"
echo "=== key format used when reading a remap ==="
grep -n 'btn\|_p%u\|key\[' "$F" 2>/dev/null | grep -iE 'snprintf|strlcpy|fill_pathname|"' | head -15
