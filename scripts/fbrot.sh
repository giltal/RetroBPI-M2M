K=~/bpi/output/build/linux-6.18.8
echo "=== does fb_helper set a rotate hint from panel orientation? ==="
grep -rn "fbcon_rotate_hint\|panel_orientation" $K/drivers/gpu/drm/drm_fb_helper.c | head -10
echo "=== rotation -> panel_orientation plumbing ==="
grep -rn "DRM_MODE_PANEL_ORIENTATION_BOTTOM_UP" $K/drivers/gpu/drm/drm_panel_orientation_quirks.c $K/drivers/gpu/drm/panel/panel-simple.c 2>/dev/null | head -5
echo "=== fbcon honours the hint only with ROTATION enabled? ==="
grep -n "fbcon_rotate_hint" $K/drivers/video/fbdev/core/fbcon.c | head
