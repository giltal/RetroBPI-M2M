#!/bin/bash
#
# Generate the Buildroot kernel patches for our panel drivers and device trees.
#
# Buildroot re-extracts the kernel on a clean build, so source edits do not
# survive — patches in BR2_GLOBAL_PATCH_DIR/linux/ are the durable mechanism.
# This script edits a pristine tree and diffs the result, rather than us
# hand-writing context diffs and getting the line numbers wrong.
#
# IMPORTANT: it must run against a PRISTINE extract. Run
#   make O=$OUT linux-dirclean linux-extract
# first. Against an already-patched tree the Kconfig/Makefile diffs come back
# empty and the emitted patches are silently incomplete.
#
set -e

PROJ="/mnt/c/BananaPi_Projects/RetroBPI_M2M"
K="$HOME/bpi/output/build/linux-6.18.8"
PATCHDIR="$PROJ/buildroot-external/board/bpi-m2m/patches/linux"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ ! -d "$K" ]; then
  echo "ERROR: kernel source not found at $K"
  exit 1
fi
mkdir -p "$PATCHDIR"

PANEL_KCONFIG="drivers/gpu/drm/panel/Kconfig"
PANEL_MAKEFILE="drivers/gpu/drm/panel/Makefile"
DTS_MAKEFILE="arch/arm/boot/dts/allwinner/Makefile"

EK_SRC="drivers/gpu/drm/panel/panel-ek79007.c"
WS_SRC="drivers/gpu/drm/panel/panel-waveshare-dsi-b.c"
DTS_EK="arch/arm/boot/dts/allwinner/sun8i-a33-bananapi-m2m-ek79007.dts"
DTS_WS="arch/arm/boot/dts/allwinner/sun8i-a33-bananapi-m2m-ws5b.dts"
DTS_PROBE="arch/arm/boot/dts/allwinner/sun8i-a33-bananapi-m2m-probe.dts"
DTS_NOUSB="arch/arm/boot/dts/allwinner/sun8i-a33-bananapi-m2m-ws5b-nousb.dts"

# --- stash pristine copies of the files we modify ------------------------
mkdir -p "$TMP/pristine"
for f in "$PANEL_KCONFIG" "$PANEL_MAKEFILE" "$DTS_MAKEFILE"; do
  mkdir -p "$TMP/pristine/$(dirname "$f")"
  cp "$K/$f" "$TMP/pristine/$f"
done

# Guard: if the tree is already patched, every modified-file diff will be
# empty and the resulting patches would be broken. Fail loudly instead.
if grep -q "DRM_PANEL_EK79007" "$K/$PANEL_KCONFIG"; then
  echo "ERROR: kernel tree is already patched."
  echo "       run 'make O=\$OUT linux-dirclean linux-extract' first."
  exit 1
fi

# --- 1. drop in the new sources -----------------------------------------
cp "$PROJ/kernel/panel-ek79007.c"                        "$K/$EK_SRC"
cp "$PROJ/kernel/panel-waveshare-dsi-b.c"                "$K/$WS_SRC"
cp "$PROJ/kernel/sun8i-a33-bananapi-m2m-ek79007.dts"     "$K/$DTS_EK"
cp "$PROJ/kernel/sun8i-a33-bananapi-m2m-ws5b.dts"        "$K/$DTS_WS"
cp "$PROJ/kernel/sun8i-a33-bananapi-m2m-probe.dts"       "$K/$DTS_PROBE"
cp "$PROJ/kernel/sun8i-a33-bananapi-m2m-ws5b-nousb.dts"  "$K/$DTS_NOUSB"

# --- 2. Kconfig entries (alphabetical: after EBBG, before ELIDA) ---------
python3 - "$K/$PANEL_KCONFIG" <<'PYEOF'
import sys
path = sys.argv[1]
src = open(path).read()
anchor = "config DRM_PANEL_ELIDA_KD35T133"
entry = """config DRM_PANEL_EK79007
	tristate "Fitipower EK79007 panel"
	depends on OF
	depends on DRM_MIPI_DSI
	depends on BACKLIGHT_CLASS_DEVICE
	help
	  Support for the Fitipower EK79007 1024x600 MIPI-DSI panel, as shipped
	  with the ESP32-P4-Function-EV-Board 7" display.

config DRM_PANEL_WAVESHARE_DSI_B
	tristate "Waveshare 5inch DSI LCD (B)"
	depends on OF
	depends on DRM_MIPI_DSI
	depends on BACKLIGHT_CLASS_DEVICE
	help
	  Support for the Waveshare 5inch DSI LCD (B), an 800x480 1-lane panel
	  built around a TC358762 DSI-to-DPI bridge with an RPi-compatible
	  ATTINY MCU on I2C. Use together with
	  REGULATOR_RASPBERRYPI_TOUCHSCREEN_ATTINY, which owns power, backlight
	  and the reset lines.

"""
assert anchor in src, "Kconfig anchor not found"
open(path, "w").write(src.replace(anchor, entry + anchor, 1))
PYEOF

# --- 3. Makefile entries -------------------------------------------------
sed -i 's|^obj-$(CONFIG_DRM_PANEL_ELIDA_KD35T133) += panel-elida-kd35t133.o|obj-$(CONFIG_DRM_PANEL_EK79007) += panel-ek79007.o\nobj-$(CONFIG_DRM_PANEL_WAVESHARE_DSI_B) += panel-waveshare-dsi-b.o\n&|' \
  "$K/$PANEL_MAKEFILE"

# --- 4. DTS Makefile entries --------------------------------------------
sed -i 's|^\tsun8i-r16-bananapi-m2m.dtb \\|\tsun8i-a33-bananapi-m2m-ek79007.dtb \\\n\tsun8i-a33-bananapi-m2m-ws5b.dtb \\\n\tsun8i-a33-bananapi-m2m-ws5b-nousb.dtb \\\n\tsun8i-a33-bananapi-m2m-probe.dtb \\\n&|' \
  "$K/$DTS_MAKEFILE"

# --- 5. emit patches -----------------------------------------------------
emit_new() {
  diff -u --label "/dev/null" --label "b/$1" /dev/null "$K/$1" > "$2" || true
  echo "  new: $1"
}
emit_modified() {
  diff -u --label "a/$1" --label "b/$1" "$TMP/pristine/$1" "$K/$1" > "$2" || true
  if [ -s "$2" ]; then
    echo "  mod: $1"
  else
    echo "  ERROR: empty diff for $1 — tree was not pristine" >&2
    exit 1
  fi
}

echo "=== generating patches ==="
{
  echo "Add EK79007 and Waveshare 5inch DSI LCD (B) panel drivers"
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
} > "$PATCHDIR/0001-drm-panel-add-panels.patch"
emit_new      "$EK_SRC"         "$TMP/a1"
emit_new      "$WS_SRC"         "$TMP/a2"
emit_modified "$PANEL_KCONFIG"  "$TMP/a3"
emit_modified "$PANEL_MAKEFILE" "$TMP/a4"
cat "$TMP/a1" "$TMP/a2" "$TMP/a3" "$TMP/a4" >> "$PATCHDIR/0001-drm-panel-add-panels.patch"

{
  echo "Add BPI-M2 Magic device trees: ek79007, ws5b and probe"
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
} > "$PATCHDIR/0002-arm-dts-bananapi-m2m-panels.patch"
emit_new      "$DTS_EK"       "$TMP/b1"
emit_new      "$DTS_WS"       "$TMP/b2"
emit_new      "$DTS_PROBE"    "$TMP/b3"
emit_new      "$DTS_NOUSB"    "$TMP/b5"
emit_modified "$DTS_MAKEFILE" "$TMP/b4"
cat "$TMP/b1" "$TMP/b2" "$TMP/b3" "$TMP/b5" "$TMP/b4" >> "$PATCHDIR/0002-arm-dts-bananapi-m2m-panels.patch"

# Drop the old split patch names if they are still lying around
rm -f "$PATCHDIR/0001-drm-panel-add-ek79007.patch" \
      "$PATCHDIR/0002-arm-dts-bananapi-m2m-ek79007.patch"

echo
echo "=== done ==="
ls -la "$PATCHDIR"

cat <<'NOTE'

IMPORTANT -- the kernel tree is now DIRTY.
This script works by editing the extracted tree and diffing it, so when it
finishes the tree already contains everything the patches describe. Building
from here fails, because Buildroot tries to apply those same patches again:

    The next patch would create the file .../panel-waveshare-dsi-b.c,
    which already exists!  Skipping patch.
    Reversed (or previously applied) patch detected!  Skipping patch.
    make: *** [.stamp_patched] Error 1

Run `make O=$OUT linux-dirclean` before building, so Buildroot re-extracts a
pristine tree and applies the freshly generated patches to it.
NOTE
