#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
echo "=== mainline DTs using simple-audio-amplifier / dio2125 ==="
grep -rln 'simple-audio-amplifier\|dioo,dio2125' $K/arch/arm/boot/dts $K/arch/arm64/boot/dts 2>/dev/null | head -8

echo
echo "=== a full example ==="
F=$(grep -rln 'simple-audio-amplifier\|dioo,dio2125' $K/arch/arm/boot/dts $K/arch/arm64/boot/dts 2>/dev/null | head -1)
echo "--- $F ---"
grep -n -B6 -A10 'simple-audio-amplifier\|dioo,dio2125' $F | head -40
echo
echo "--- how it is wired into the card in that file ---"
grep -n -A14 'aux-devs' $F | head -30

echo
echo "=== A33 analog codec DAPM widgets (what can we route from?) ==="
grep -nE 'SND_SOC_DAPM_OUTPUT|SND_SOC_DAPM_INPUT' $K/sound/soc/sunxi/sun8i-codec-analog.c | head -20

echo
echo "=== is there a codec_analog label in the a33 dtsi? ==="
grep -n 'codec_analog' $K/arch/arm/boot/dts/allwinner/sun8i-a33.dtsi
