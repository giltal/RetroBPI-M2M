#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
F=$K/arch/arm64/boot/dts/rockchip/rk3566-anbernic-rg353p.dts
B=$K/arch/arm64/boot/dts/rockchip/rk3566-anbernic-rg353x.dtsi
echo "=== anbernic amp node ==="
grep -n -B3 -A8 'simple-audio-amplifier' $F $B 2>/dev/null | head -30
echo
echo "=== its sound card + routing ==="
grep -n -A25 'compatible = "simple-audio-card"' $B 2>/dev/null | head -35
echo
echo "=== omap3-echo full sound node (routing style) ==="
sed -n '98,122p' $K/arch/arm/boot/dts/ti/omap/omap3-echo.dts
echo
echo "=== where is codec_analog defined? ==="
grep -rn 'codec_analog:' $K/arch/arm/boot/dts/allwinner/ | head -3
