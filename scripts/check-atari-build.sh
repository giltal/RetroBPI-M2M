#!/bin/bash
SRC=$(ls -d ~/bpi/output/build/libretro-atari800-*/ | head -1)
echo "source: $SRC"
echo
echo "=== sound-related switches in the core Makefile ==="
grep -inE 'sound|SOUND' $SRC/Makefile 2>/dev/null | head -20
echo
echo "=== what our build actually passed ==="
grep -m3 -iE 'platform=|CFLAGS' ~/bpi/corelogs/atari800p.log 2>/dev/null | head -5
echo
echo "=== is SOUND defined in the compile lines? ==="
grep -o -- '-DSOUND[A-Z_]*' ~/bpi/corelogs/atari800p.log 2>/dev/null | sort -u | head
echo "  (empty = sound never defined at compile time)"
echo
echo "=== does the built object set include the sound sources? ==="
grep -o -- 'pokeysnd\.o\|sound\.o\|sndsave\.o\|pokey\.o' ~/bpi/corelogs/atari800p.log 2>/dev/null | sort -u | head
