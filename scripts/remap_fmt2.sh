#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/retroarch-* | head -1)
echo "=== the key-building code (configuration.c ~6570-6600) ==="
sed -n '6570,6605p' "$D/configuration.c"
echo
echo "=== auto_remaps_enable default and remap dir default ==="
grep -rn 'DEFAULT_AUTO_REMAPS_ENABLE' "$D"/*.h "$D"/config.def.h 2>/dev/null | head -3
