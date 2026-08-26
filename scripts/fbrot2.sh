K=~/bpi/output/build/linux-6.18.8
echo "=== fb_helper rotation source (1770-1800) ==="
sed -n "1770,1802p" $K/drivers/gpu/drm/drm_fb_helper.c
echo "=== fbcon con_rotate guarded by ROTATION? (975-995) ==="
sed -n "975,995p" $K/drivers/video/fbdev/core/fbcon.c
echo "=== does panel-simple parse the DT rotation property? ==="
grep -rn "of_drm_get_panel_orientation\|rotation" $K/drivers/gpu/drm/panel/panel-simple.c | head -5
