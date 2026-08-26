#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
R=$(ls -d /home/giltal/bpi/output/build/retroarch-*/ 2>/dev/null | head -1)

echo "=== 1. Does sun4i-drm expose a hardware plane rotation property? ==="
grep -rn 'rotation' $K/drivers/gpu/drm/sun4i/*.c 2>/dev/null | head -10
echo "  (no output = no hardware rotation; must be done in userspace)"

echo
echo "=== 2. Does the DRM panel infrastructure read a DT 'rotation' property? ==="
grep -rn 'of_drm_get_panel_orientation' $K/drivers/gpu/drm/drm_panel.c | head -3
echo "  -- that sets a connector HINT for userspace; the kernel does not rotate --"

echo
echo "=== 3. RetroArch rotation support ==="
grep -rn 'video_rotation' $R/configuration.c 2>/dev/null | head -3
echo "  --- does the GL driver apply it? ---"
grep -rn 'rotation' $R/gfx/drivers/gl2.c 2>/dev/null | head -6

echo
echo "=== 4. fbcon rotation available in our kernel config? ==="
grep -E 'CONFIG_FRAMEBUFFER_CONSOLE_ROTATION|CONFIG_FRAMEBUFFER_CONSOLE=' $K/.config
