#!/bin/sh
D=$(ls -d $HOME/bpi/output/build/retroarch-* | head -1)
echo "=== remap key format in RetroArch source ==="
grep -rn 'input_remap_id_p%u_btn\|input_remap_id_p%u\|"btn"' "$D/configuration.c" "$D/tasks/task_content.c" 2>/dev/null | head -8
echo
echo "=== remap directory setting ==="
grep -rn 'input_remapping_directory\|remaps' "$D/configuration.c" 2>/dev/null | head -6
echo
echo "=== how a remap file is named ==="
grep -rn 'rmp' "$D/configuration.c" "$D/retroarch.c" 2>/dev/null | head -8
