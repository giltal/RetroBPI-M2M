#!/bin/bash
S=/home/giltal/bpi/output/build/linux-6.18.8/sound/soc/sunxi/sun8i-codec-analog.c
echo "=== every HP mention in the analog codec driver ==="
grep -n 'HP\|hp' $S | grep -viE 'help|https' | head -60
