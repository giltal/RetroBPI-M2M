#!/bin/bash
set -e
SRC=$(ls -d ~/bpi/output/build/libretro-pcsx-*/ | head -1)
F=Makefile
OUT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external/package/retroarch/libretro-pcsx
T=$(mktemp -d); trap 'rm -rf $T' EXIT

echo "=== context around the cdrom object ==="
grep -n -B3 -A3 'frontend/libretro-cdrom.o' "$SRC/$F"

cp "$SRC/$F" "$T/orig"
cp "$SRC/$F" "$T/new"

python3 - "$T/new" <<'PYEOF'
import sys
path = sys.argv[1]
LF, CRLF = chr(10), chr(13) + chr(10)
raw = open(path, newline='').read()
nl  = CRLF if CRLF in raw else LF
lines = raw.split(nl)

for i, l in enumerate(lines):
    if 'OBJS += frontend/libretro-cdrom.o' in l:
        block = [
'# libretro-cdrom.c calls dir_list_new() and compat_strcasestr(), but neither',
'# object is in the list above. The C compiles -- the headers declare them --',
'# so the build succeeds and produces a .so with two undefined symbols, which',
'# only shows up when the frontend tries to dlopen it and reports the unhelpful',
'# "Failed to open libretro core".',
'OBJS += deps/libretro-common/lists/dir_list.o',
'OBJS += deps/libretro-common/compat/compat_strcasestr.o',
        ]
        lines[i+1:i+1] = block
        break
else:
    sys.exit('ERROR: libretro-cdrom.o anchor not found')

open(path, 'w', newline='').write(nl.join(lines))
print('  objects added')
PYEOF

cd "$T"
{
  echo "pcsx_rearmed: link the objects libretro-cdrom.c needs"
  echo
  echo "frontend/libretro-cdrom.c references dir_list_new() and compat_strcasestr()"
  echo "but neither object is in OBJS, so the core links with undefined symbols and"
  echo "cannot be dlopen'd."
  echo
  echo "Signed-off-by: RetroBPI_M2M"
  echo
  diff -u --label "a/$F" --label "b/$F" orig new || true
} > "$OUT/0001-pcsx-link-dir_list-and-compat_strcasestr.patch"

echo "  patch lines: $(wc -l < "$OUT/0001-pcsx-link-dir_list-and-compat_strcasestr.patch")"
