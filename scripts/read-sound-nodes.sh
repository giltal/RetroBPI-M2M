#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8/arch/arm/boot/dts/allwinner
echo "=== sun8i-r16-bananapi-m2m.dts : &codec ==="
sed -n '95,120p' $K/sun8i-r16-bananapi-m2m.dts
echo
echo "=== sun8i-r16-bananapi-m2m.dts : &sound ==="
sed -n '264,300p' $K/sun8i-r16-bananapi-m2m.dts
echo
echo "=== sun8i-a33.dtsi : sound node ==="
sed -n '183,210p' $K/sun8i-a33.dtsi
echo
echo "=== codec node ==="
sed -n '240,262p' $K/sun8i-a33.dtsi
