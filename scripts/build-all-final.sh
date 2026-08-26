#!/bin/bash
set -e
cd ~/bpi/buildroot
export BR2_DL_DIR=~/bpi/dl
EXT=/mnt/c/BananaPi_Projects/RetroBPI_M2M/buildroot-external
O=~/bpi/output

echo "=== regenerate .config (picks up PARALLELN64) ==="
make BR2_EXTERNAL=$EXT O=$O bpi_m2m_retro_defconfig 2>&1 | tail -3
echo "  cores selected: $(grep -cE '^BR2_PACKAGE_LIBRETRO.*=y' $O/.config)"

echo
echo "=== rebuild the launcher (system table changed: GBA->mGBA, +N64) ==="
make O=$O retrobpi-launcher-rebuild 2>&1 | tail -4

echo
echo "=== full build ==="
make O=$O -j$(nproc) 2>&1 | tail -6

echo
echo "=== cores in the rootfs image ==="
IMG=$O/images/rootfs.ext4
debugfs -R "ls -l usr/lib/libretro" $IMG 2>/dev/null | awk '{print $NF}' | grep '_libretro.so' | sort | tr '\n' ' '
echo
echo "  count: $(debugfs -R 'ls -l usr/lib/libretro' $IMG 2>/dev/null | grep -c '_libretro.so')"

echo
echo "=== launcher table sanity (inside the image) ==="
rm -rf /tmp/fin && mkdir -p /tmp/fin
debugfs -R "dump usr/bin/retrobpi_launcher /tmp/fin/launcher" $IMG 2>/dev/null
# gpsp is the GBA core (ARM dynarec), NOT mgba -- mgba is an interpreter and
# does not hold 60 fps here. Both ship; the table must point at gpsp.
for want in gpsp_libretro.so paralleln64_libretro.so mame2003plus_libretro.so; do
    if strings /tmp/fin/launcher | grep -q "$want"; then echo "  OK   table references $want"; else echo "  MISS $want"; fi
done
echo "  --- gpsp must have the dynarec, not be an interpreter-only build ---"
rm -f /tmp/fin/gpsp.so
debugfs -R "dump usr/lib/libretro/gpsp_libretro.so /tmp/fin/gpsp.so" $IMG 2>/dev/null
if strings /tmp/fin/gpsp.so | grep -q translate_block_arm; then
    echo "  OK   gpsp dynarec present"
else
    echo "  !!   gpsp built WITHOUT the dynarec -- GBA will be slow"
fi

echo
echo "=== per-core overrides present, and enabled in retroarch.cfg? ==="
debugfs -R "ls root/.config/retroarch/config" $IMG 2>/dev/null | tr -s ' ' '\n' | grep -viE '^\.|^[0-9]+$|^$' | tr '\n' ' '
echo
debugfs -R "dump root/.config/retroarch/retroarch.cfg /tmp/fin/ra.cfg" $IMG 2>/dev/null
grep -E '^(auto_overrides_enable|global_core_options|input_volume)' /tmp/fin/ra.cfg

echo
echo "=== ROM folders on the FAT partition ==="
mdir -/ -i $O/images/roms.vfat :: 2>/dev/null | grep -oE '^[a-z0-9_]+' | tr '\n' ' ' || echo "  (mdir unavailable)"
echo
ls -l $O/images/sdcard.img
cp $O/images/sdcard.img /mnt/c/BananaPi_Projects/RetroBPI_M2M/firmware/sdcard.img
echo BUILD_ALL_FINAL_DONE
