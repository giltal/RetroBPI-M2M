#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
F=$K/drivers/input/touchscreen/edt-ft5x06.c
echo "=== the ISR in full ==="
sed -n '/static irqreturn_t edt_ft5x06_ts_isr/,/^}/p' $F
