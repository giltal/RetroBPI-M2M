#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/retroarch-* | head -1)
echo "=== files handling remaps ==="
ls "$D"/*remap* "$D"/input/*remap* 2>/dev/null
echo
echo "=== the remap key strings ==="
grep -rn 'input_remap_id_p\|_btn%u\|snprintf(.*remap' "$D"/*remap*.c "$D"/input/*remap*.c 2>/dev/null | head -12
