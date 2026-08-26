#!/bin/bash
SO=~/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "=== option definitions (Description; value|value|...) ==="
strings "$SO" | grep -E '^[A-Z][^;]*; [^|]+\|' | head -25
echo
echo "=== single-value / toggle options ==="
strings "$SO" | grep -E '^[A-Z][^;]*; (enabled|disabled)\|' | head -15
