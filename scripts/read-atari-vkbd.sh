#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-atari800-*/ | head -1)
F=$SRC/libretro/core-mapper.c
echo "=== vkbd section: how is it opened/closed? (lines 245-330) ==="
sed -n '245,330p' $F
echo
echo "=== the SHOWKEY==-1 guard and function start (505-530) ==="
sed -n '505,530p' $F
echo
echo "=== exact line of the closing brace before the else (joystick block) ==="
grep -n 'else         //Emulate joystick controls' $F
