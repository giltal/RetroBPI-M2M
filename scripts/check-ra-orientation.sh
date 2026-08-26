#!/bin/bash
R=$(ls -d ~/bpi/output/build/retroarch-*/ | head -1)
echo "=== is there a screen_orientation setting? ==="
grep -rn 'screen_orientation' $R/configuration.c | head -5
echo
echo "=== how is it applied? ==="
grep -rn 'screen_orientation\|set_screen_orientation' $R/retroarch.c $R/gfx/video_driver.c 2>/dev/null | head -10
echo
echo "=== does the KMS/DRM-backed GL path implement it? ==="
grep -rn 'set_screen_orientation' $R/gfx/drivers_context/*.c 2>/dev/null | head -10
echo "  (empty = the kms context does not implement display rotation)"
echo
echo "=== does the menu draw with a rotated MVP? ==="
grep -n 'mvp_no_rot\|mvp' $R/gfx/drivers/gl2.c | head -20
