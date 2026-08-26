D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== core_settings_autoselect_rsp_plugin (297-335) ==="
sed -n "297,335p" $D/libretro/libretro.c
echo "=== caller at ~690-700 ==="
sed -n "688,702p" $D/libretro/libretro.c
echo "=== rspplugin option read (275-296) ==="
sed -n "272,296p" $D/libretro/libretro.c
