#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8/arch/arm/boot/dts/allwinner
echo "=== audio nodes in the base board DTS ==="
grep -nE 'codec|sound|audio|dai_link|&codec' $K/sun8i-r16-bananapi-m2m.dts

echo
echo "=== codec / audio nodes in sun8i-a33.dtsi ==="
grep -nE '^\s+(sound|codec|dai)|compatible = "allwinner,sun8i-a33-(codec|codec-analog)"|allwinner,sun4i-a10-codec' $K/sun8i-a33.dtsi | head -20

echo
echo "=== is PH9 used anywhere in the DTS chain? ==="
for f in sun8i-r16-bananapi-m2m.dts sun8i-a33.dtsi sun8i-a23-a33.dtsi; do
    echo "--- $f ---"
    grep -nE 'pio 7 9|PH9|ph9' $K/$f 2>/dev/null || echo "   (PH9 not referenced)"
done

echo
echo "=== simple-amplifier driver: what does the binding want? ==="
S=/home/giltal/bpi/output/build/linux-6.18.8/sound/soc/codecs/simple-amplifier.c
grep -nE 'compatible|enable-gpios|VCC|of_device_id|\.name|SND_SOC_DAPM|snd_soc_dapm_widget|route' $S | head -30

echo
echo "=== is the amplifier driver enabled in our kernel? ==="
grep -E 'CONFIG_SND_SOC_SIMPLE_AMPLIFIER|CONFIG_SND_SIMPLE_CARD' /home/giltal/bpi/output/build/linux-6.18.8/.config
