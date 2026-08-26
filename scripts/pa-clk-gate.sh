#!/bin/bash
S=/home/giltal/bpi/output/build/linux-6.18.8/sound/soc/sunxi/sun8i-codec-analog.c
echo "=== is PA_CLK_GATE ever written? ==="
grep -n 'PA_CLK_GATE' $S
echo
echo "=== context around every use ==="
grep -n -B8 -A12 'PA_CLK_GATE' $S
echo
echo "=== LTRNMUTE / RTLNMUTE usage ==="
grep -n -B4 -A8 'LTRNMUTE\|RTLNMUTE' $S
