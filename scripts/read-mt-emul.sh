#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
echo "=== input_mt_report_pointer_emulation ==="
sed -n '/void input_mt_report_pointer_emulation/,/^}/p' $K/drivers/input/input-mt.c
