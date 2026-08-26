#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
D=$K/arch/arm/boot/dts/allwinner
echo "=== codec_analog node (where is it defined, what supplies?) ==="
grep -rn -A10 'codec_analog: codec-analog' $D/sun8i-a23-a33.dtsi $D/sun8i-a33.dtsi 2>/dev/null

echo
echo "=== does the board DTS give it a supply? ==="
grep -n -B3 -A6 'codec_analog\|cpvdd' $D/sun8i-r16-bananapi-m2m.dts

echo
echo "=== what does the driver require? ==="
grep -n -B3 -A12 'cpvdd\|regulator' $K/sound/soc/sunxi/sun8i-codec-analog.c | head -40

echo
echo "=== HP-related DAPM widgets and supplies in the analog codec ==="
sed -n '/sun8i_a23_codec_analog_widgets\|a23_codec_analog_widgets/,/^};/p' $K/sound/soc/sunxi/sun8i-codec-analog.c | grep -nE 'SND_SOC_DAPM|HP' | head -30

echo
echo "=== HP routes ==="
sed -n '/a23_codec_analog_routes\|sun8i_a23_codec_analog_routes/,/^};/p' $K/sound/soc/sunxi/sun8i-codec-analog.c | grep -i 'hp' | head -20
