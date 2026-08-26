#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/retroarch-* | head -1)
F=$D/input/input_driver.c
echo "=== remap key construction in input_driver.c ==="
grep -n 'btn' "$F" | grep -iE 'snprintf|_p%u|key' | head -12
echo
echo "--- context around the load function ---"
L=$(grep -n 'input_remapping_load_file' "$F" | head -1 | cut -d: -f1)
echo "load fn at line $L"
sed -n "$((L)),$((L+45))p" "$F" | grep -nE 'snprintf|btn|prefix|key' | head -20
