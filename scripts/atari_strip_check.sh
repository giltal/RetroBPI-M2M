#!/bin/sh
T=$HOME/bpi/output/target/usr/lib/libretro/atari800_libretro.so
echo "image-tree core:"
echo "  size    : $(stat -c %s $T 2>/dev/null || wc -c < $T)"
echo "  md5     : $(md5sum $T | cut -d' ' -f1)"
echo "  stripped: $(file $T | grep -o 'not stripped\|stripped')"
echo "  R-patch : $(strings $T | grep -c 'Virtual Keyboard (alt)')"
