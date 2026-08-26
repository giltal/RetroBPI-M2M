#!/bin/bash
set -e
SRC=$(ls -d ~/bpi/output/build/libretro-fuse-*/ | head -1)
F=src/compat/ui.c
OUT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/board/bpi-m2m/patches/libretro-fuse
mkdir -p "$OUT"
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

anchor = None
for i, l in enumerate(lines):
    if l.strip() == 'int16_t is_down = 0;':
        anchor = i
        break
if anchor is None:
    sys.exit('ERROR: anchor "int16_t is_down = 0;" not found')

block = [
'',
'   /*',
'    * L1 also toggles the keyboard overlay, unconditionally.',
'    *',
'    * The Spectrum is a keyboard machine and this device has no keyboard, so',
'    * reaching the overlay matters. Upstream only checks SELECT, and only',
'    * inside the switch below -- i.e. only when the port has been set to one of',
'    * the joystick device types. If the device type is anything else the toggle',
'    * never fires and the overlay is unreachable.',
'    *',
'    * Checking L1 here, before the switch, makes it work whatever the port is',
'    * set to, and leaves SELECT free for the game.',
'    */',
'   is_down |= input_state_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L);',
]

lines[anchor+1:anchor+1] = block
open(path, 'w', newline='').write(nl.join(lines))
print('  inserted after line ' + str(anchor+1) + ' (' + ('CRLF' if nl == CRLF else 'LF') + ' preserved)')
PYEOF

cd "$T"
{
  echo "fuse: let L1 toggle the keyboard overlay unconditionally"
  echo
  echo "Upstream only checks SELECT, and only when the port device is one of the"
  echo "joystick types. If it is not, the on-screen keyboard cannot be reached at"
  echo "all -- which matters on a handheld with no keyboard."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  diff -u --label "a/$F" --label "b/$F" orig.c new.c || true
} > "$OUT/0001-fuse-L1-toggles-keyboard-overlay.patch"

echo "  patch lines: $(wc -l < "$OUT/0001-fuse-L1-toggles-keyboard-overlay.patch")"
echo "  hunks: $(grep -c '^@@' "$OUT/0001-fuse-L1-toggles-keyboard-overlay.patch")"
