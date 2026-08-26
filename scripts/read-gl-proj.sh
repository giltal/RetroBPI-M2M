#!/bin/bash
R=$(ls -d ~/bpi/output/build/retroarch-*/ | head -1)
echo "=== gl2_set_projection ==="
sed -n '/static void gl2_set_projection/,/^}/p' $R/gfx/drivers/gl2.c
