#!/bin/bash
O=~/bpi/output
RE=$(ls $O/host/bin/*-readelf | head -1)
SO=$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so

echo "=== md5 of the core we built ==="
md5sum "$SO" | cut -d' ' -f1

echo
echo "=== undefined dynamic symbols NOT satisfied by libc/libm ==="
# collect what libc/libm export
$RE --dyn-syms -W $O/target/lib/libc.so.6 2>/dev/null | awk '$7!="UND"{print $8}' | sed 's/@.*//' | sort -u > /tmp/libc.syms
$RE --dyn-syms -W $O/target/lib/libm.so.6 2>/dev/null | awk '$7!="UND"{print $8}' | sed 's/@.*//' | sort -u > /tmp/libm.syms
cat /tmp/libc.syms /tmp/libm.syms | sort -u > /tmp/avail.syms
echo "  symbols exported by libc+libm: $(wc -l < /tmp/avail.syms)"

$RE --dyn-syms -W "$SO" 2>/dev/null | awk '$7=="UND"{print $8}' | sed 's/@.*//' | sort -u > /tmp/psx.und
echo "  undefined in pcsx: $(wc -l < /tmp/psx.und)"
echo "  --- not found in libc/libm ---"
comm -23 /tmp/psx.und /tmp/avail.syms | head -20
n=$(comm -23 /tmp/psx.und /tmp/avail.syms | wc -l)
echo "  ($n unresolved)"

echo
echo "=== same check for a core that loads ==="
$RE --dyn-syms -W $O/target/usr/lib/libretro/fceumm_libretro.so 2>/dev/null | awk '$7=="UND"{print $8}' | sed 's/@.*//' | sort -u > /tmp/fce.und
echo "  fceumm unresolved: $(comm -23 /tmp/fce.und /tmp/avail.syms | wc -l)"
comm -23 /tmp/fce.und /tmp/avail.syms | head -5
