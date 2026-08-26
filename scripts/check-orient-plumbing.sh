#!/bin/bash
K=/home/giltal/bpi/output/build/linux-6.18.8
echo "=== how do panel drivers publish orientation? (reference: a mainline panel) ==="
grep -rln 'of_drm_get_panel_orientation' $K/drivers/gpu/drm/panel/ | head -3
F=$(grep -rln 'of_drm_get_panel_orientation' $K/drivers/gpu/drm/panel/ | head -1)
echo "--- $F ---"
grep -n -B3 -A3 'of_drm_get_panel_orientation' $F | head -15

echo
echo "=== does the connector pick it up automatically? ==="
grep -rn 'drm_connector_set_panel_orientation\|panel->orientation' $K/drivers/gpu/drm/drm_panel.c $K/drivers/gpu/drm/drm_bridge_connector.c $K/drivers/gpu/drm/bridge/panel.c 2>/dev/null | head -10

echo
echo "=== the connector property userspace would read ==="
grep -rn '\"panel orientation\"' $K/drivers/gpu/drm/drm_connector.c | head -3
