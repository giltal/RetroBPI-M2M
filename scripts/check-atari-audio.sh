#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/atari800_libretro.so
echo "=== atari800 core options (Description; values) ==="
strings "$SO" | grep -E '^[A-Za-z][^;]*; [^|]+\|' | head -20
echo
echo "=== option keys ==="
strings "$SO" | grep -E '^atari800_' | head -20
echo
echo "=== anything sound/pokey related ==="
strings "$SO" | grep -iE 'sound|pokey|audio|stereo|samplerate|sample_rate' | head -15
