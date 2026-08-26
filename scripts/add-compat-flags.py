#!/usr/bin/env python3
"""
Add $(LIBRETRO_COMPAT_CFLAGS) to a libretro core's .mk.

These cores were written for roughly GCC 8 and this toolchain is GCC 14, which
changed several C defaults: -fno-common became the default in GCC 10 (so the
cores' tentative definitions now collide at link time) and GCC 14 promoted
incompatible-pointer-types and friends from warnings to errors. Neither is a
bug in the emulation, so the fix is to restore the old behaviour per core.

Usage: add-compat-flags.py <core> [<core> ...]
"""
import sys, os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    '..', 'buildroot-external', 'package', 'retroarch')
NEEDLE = 'CFLAGS="$(TARGET_CFLAGS)'
INSERT = ' $(LIBRETRO_COMPAT_CFLAGS)'

rc = 0
for core in sys.argv[1:]:
    path = os.path.normpath(os.path.join(BASE, 'libretro-%s' % core,
                                         'libretro-%s.mk' % core))
    if not os.path.isfile(path):
        print('  MISSING  %s' % path); rc = 1; continue

    src = open(path, encoding='utf-8').read()
    if 'LIBRETRO_COMPAT_CFLAGS' in src:
        print('  already  %s' % core); continue
    if NEEDLE not in src:
        print('  NO CFLAGS ANCHOR  %s  (needs hand editing)' % core); rc = 1; continue

    i = src.index(NEEDLE) + len(NEEDLE)
    src = src[:i] + INSERT + src[i:]
    open(path, 'w', encoding='utf-8', newline='\n').write(src)
    print('  patched  %s' % core)

sys.exit(rc)
