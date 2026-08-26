#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-pcsx-*/ | head -1)
echo "=== includes in Makefile.libretro ==="
grep -nE '^[[:space:]]*(-?include|OBJS|SOURCES)' "$SRC/Makefile.libretro" | head -20
echo
echo "=== who actually calls dir_list_new / compat_strcasestr? ==="
grep -rln 'dir_list_new\|compat_strcasestr' "$SRC" --include='*.c' --include='*.h' 2>/dev/null | grep -v 'deps/libretro-common' | head
echo
echo "=== is libretro-cdrom.c in the build? ==="
grep -rn 'libretro-cdrom' "$SRC/Makefile"* 2>/dev/null | head -5
echo
echo "=== what the link line actually included (from the build log) ==="
grep -oE '[a-zA-Z0-9_/.-]+\.o' ~/bpi/corelogs/pcsx2.log | sort -u | grep -cE '.'
grep -oE 'deps/libretro-common[a-zA-Z0-9_/.-]*\.o' ~/bpi/corelogs/pcsx2.log | sort -u | head -10
echo "  (above: libretro-common objects that made it into the build)"
