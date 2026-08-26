#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
F=$K/drivers/input/touchscreen/edt-ft5x06.c
echo "=== how the ISR reports touches ==="
sed -n '/static irqreturn_t edt_ft5x06_ts_isr/,/^}/p' $F | grep -nE 'input_mt|input_report|input_sync|BTN_TOUCH|num_points|for ' | head -20
echo
echo "=== MT slot init flags ==="
grep -n 'input_mt_init_slots' $F
echo
echo "=== is pointer emulation (and thus BTN_TOUCH) requested? ==="
grep -n 'INPUT_MT_DIRECT\|INPUT_MT_POINTER\|input_mt_report_pointer_emulation\|input_mt_sync_frame' $F
