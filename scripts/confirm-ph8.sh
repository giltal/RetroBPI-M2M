#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8/arch/arm/boot/dts/allwinner
echo "=== what pin does mainline assign to usb0_id_det on this board? ==="
grep -n -B2 -A2 'usb0_id_det' $K/sun8i-r16-bananapi-m2m.dts
