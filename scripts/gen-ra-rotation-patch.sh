#!/bin/bash
set -e
SRC=$(ls -d ~/bpi/output/build/retroarch-*/ | head -1)
F=gfx/drivers/gl2.c
OUT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/package/retroarch/retroarch
T=$(mktemp -d); trap 'rm -rf $T' EXIT

cp "$SRC/$F" "$T/orig.c"
cp "$SRC/$F" "$T/new.c"

python3 - "$T/new.c" <<'PYEOF'
import sys
path = sys.argv[1]
LF, CRLF = chr(10), chr(13) + chr(10)
raw = open(path, newline='').read()
nl  = CRLF if CRLF in raw else LF
lines = raw.split(nl)

# Insert straight after the base ortho projection is built, so BOTH mvp and
# mvp_no_rot inherit the display rotation.
anchor = None
for i, l in enumerate(lines):
    if 'ortho->bottom, ortho->top, ortho->znear, ortho->zfar);' in l:
        anchor = i
        break
if anchor is None:
    sys.exit('ERROR: ortho anchor not found')

block = [
'',
'#if defined(RETROBPI_DISPLAY_ROTATION) && RETROBPI_DISPLAY_ROTATION != 0',
'   /*',
'    * Fold a fixed DISPLAY rotation into the base projection.',
'    *',
'    * The panel on this board is mounted upside down. RetroArch\'s own',
'    * video_rotation is a CONTENT rotation: it is applied to gl->mvp only,',
'    * while the menu, OSD and every gfx_display widget deliberately draw with',
'    * gl->mvp_no_rot so they stay screen-upright when a vertical arcade game',
'    * rotates. Correct in general -- wrong when the whole panel is upside',
'    * down, which showed up as the game rotating but the RGUI menu and',
'    * on-screen messages staying inverted.',
'    *',
'    * screen_orientation is the setting that would normally cover this, but',
'    * the KMS context does not implement set_screen_orientation (it is NULL',
'    * in video_driver.c), so it is a no-op here.',
'    *',
'    * Rotating mvp_no_rot itself means everything inherits it, and the core',
'    * rotation still composes on top for vertical games.',
'    */',
'   {',
'      math_matrix_4x4 disp, tmp;',
'      float drad = M_PI * (RETROBPI_DISPLAY_ROTATION) / 180.0f;',
'      matrix_4x4_identity(disp);',
'      MAT_ELEM_4X4(disp, 0, 0) =  cosf(drad);',
'      MAT_ELEM_4X4(disp, 0, 1) = -sinf(drad);',
'      MAT_ELEM_4X4(disp, 1, 0) =  sinf(drad);',
'      MAT_ELEM_4X4(disp, 1, 1) =  cosf(drad);',
'      matrix_4x4_multiply(tmp, disp, gl->mvp_no_rot);',
'      gl->mvp_no_rot = tmp;',
'   }',
'#endif',
]

lines[anchor+1:anchor+1] = block
open(path, 'w', newline='').write(nl.join(lines))
print('  inserted after line ' + str(anchor+1))
PYEOF

cd "$T"
{
  echo "gl2: fold a fixed display rotation into the base projection"
  echo
  echo "video_rotation is a content rotation and is applied to mvp only; the menu"
  echo "and OSD draw with mvp_no_rot by design. On a board whose panel is mounted"
  echo "upside down that leaves the menu inverted. screen_orientation would be the"
  echo "right knob but the KMS context does not implement it."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  diff -u --label "a/$F" --label "b/$F" orig.c new.c || true
} > "$OUT/0007-gl2-fold-display-rotation-into-base-projection.patch"

echo "  patch lines: $(wc -l < "$OUT/0007-gl2-fold-display-rotation-into-base-projection.patch")"
echo "  hunks: $(grep -c '^@@' "$OUT/0007-gl2-fold-display-rotation-into-base-projection.patch")"
