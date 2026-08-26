#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-pcsx-*/ | head -1)
echo "source: $SRC"
echo
echo "=== where do those symbols live? ==="
grep -rln 'compat_strcasestr' "$SRC/libretro-common" 2>/dev/null | head -3
grep -rln 'dir_list_new' "$SRC/libretro-common" 2>/dev/null | head -3
echo
echo "=== are those files in the Makefile's object list? ==="
grep -nE 'compat_strcasestr|dir_list|libretro-common' "$SRC/Makefile.libretro" 2>/dev/null | head -20
echo
echo "=== what platform did our build resolve to? ==="
grep -m2 -oE 'platform="[^"]*"' ~/bpi/corelogs/pcsx.log
echo
echo "=== does the Makefile branch on platform for these objects? ==="
grep -nE 'ifeq.*platform|OBJS.*libretro-common|SOURCES_C.*libretro-common' "$SRC/Makefile.libretro" 2>/dev/null | head -15
