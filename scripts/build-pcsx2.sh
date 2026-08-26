#!/bin/bash
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
O=~/bpi/output

echo "=== rebuild pcsx with platform=unix ==="
make O=$O libretro-pcsx-dirclean >/dev/null 2>&1
if make O=$O libretro-pcsx > ~/bpi/corelogs/pcsx2.log 2>&1; then
    echo "  BUILD OK"
else
    echo "  BUILD FAILED"; grep -iE 'error:|Error [0-9]+$' ~/bpi/corelogs/pcsx2.log | head -10; exit 1
fi

SO=$O/target/usr/lib/libretro/pcsx_rearmed_libretro.so
RE=$(ls $O/host/bin/*-readelf | head -1)
ls -l $SO

echo
echo "=== THE test: any unresolved symbols left? ==="
$RE --dyn-syms -W $O/target/lib/libc.so.6 2>/dev/null | awk '$7!="UND"{print $8}' | sed 's/@.*//' | sort -u >  /tmp/avail.syms
$RE --dyn-syms -W $O/target/lib/libm.so.6 2>/dev/null | awk '$7!="UND"{print $8}' | sed 's/@.*//' | sort -u >> /tmp/avail.syms
sort -u /tmp/avail.syms -o /tmp/avail.syms
$RE --dyn-syms -W "$SO" 2>/dev/null | awk '$7=="UND"{print $8}' | sed 's/@.*//' | sort -u > /tmp/psx.und
echo "  unresolved (weak _ITM_/__gmon_/__stack_chk_guard are normal):"
comm -23 /tmp/psx.und /tmp/avail.syms | sed 's/^/    /'
real=$(comm -23 /tmp/psx.und /tmp/avail.syms | grep -vE '_ITM_|__gmon_start__|__stack_chk_guard' | wc -l)
echo "  --- $real genuinely unresolved ---"
[ "$real" -eq 0 ] && echo "  OK: should dlopen now" || { echo "  !! still broken"; exit 1; }

echo
echo "=== ARM features still on? ==="
strings "$SO" | grep -m1 -E 'cc .*armv7|gpu=neon|ari64'
echo
md5sum "$SO" | cut -d' ' -f1
cp "$SO" /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/psx/pcsx_rearmed_libretro.so
echo BUILD_PCSX2_DONE
