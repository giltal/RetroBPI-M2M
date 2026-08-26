#!/bin/bash
S=/home/giltal/bpi/output/build/linux-6.18.8/sound/soc/sunxi/sun8i-codec.c
echo "=== volume TLV scales ==="
grep -n 'DECLARE_TLV' $S
echo
echo "=== AIF1 DA0 Playback Volume control definition ==="
grep -n -B4 -A6 'AIF1 DA0 Playback Volume' $S
echo
echo "=== DAC Playback Volume control definition ==="
grep -n -B2 -A6 '"DAC Playback Volume"' $S
echo
echo "=== the register defaults ==="
grep -n -A20 'sun8i_codec_reg_defaults\|reg_defaults' $S | head -30
