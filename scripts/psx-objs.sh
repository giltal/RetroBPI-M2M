#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-pcsx-*/ | head -1)
M="$SRC/Makefile.libretro"
echo "=== how libretro-common objects are added ==="
grep -nE 'deps/libretro-common|LIBRETRO_COMM|libretro_common' "$M" | head -20
echo
echo "=== which libretro-common .c files ARE in the object list? ==="
grep -oE 'deps/libretro-common/[a-z_/]+\.c' "$M" | sort -u | head -20
echo
echo "=== is dir_list.c or compat_strcasestr.c mentioned at all? ==="
grep -nE 'dir_list|strcasestr' "$M" || echo "  neither is referenced by the Makefile"
echo
echo "=== who needs them? ==="
grep -rln 'dir_list_new\|compat_strcasestr' "$SRC/frontend"/*.c 2>/dev/null | head
