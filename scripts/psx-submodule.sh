#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-pcsx-*/ | head -1)
echo "source: $SRC"
echo
echo "=== is there a libretro-common directory, and is it populated? ==="
for d in libretro-common frontend/libretro-common deps/libretro-common; do
    if [ -d "$SRC/$d" ]; then
        echo "  $d exists, $(find "$SRC/$d" -type f | wc -l) files"
    else
        echo "  $d ABSENT"
    fi
done
echo
echo "=== does the repo declare submodules? ==="
cat "$SRC/.gitmodules" 2>/dev/null || echo "  no .gitmodules in the tarball"
echo
echo "=== where does the Makefile expect these sources? ==="
grep -nE 'libretro-common|LIBRETRO_COMM_DIR' "$SRC/Makefile.libretro" 2>/dev/null | head -10
echo
echo "=== do the functions exist anywhere in the tree? ==="
grep -rln 'compat_strcasestr' "$SRC" 2>/dev/null | head -3
grep -rln 'dir_list_new' "$SRC" 2>/dev/null | head -3
