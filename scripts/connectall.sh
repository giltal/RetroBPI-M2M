D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== plugin_connect_all: how gfx table is chosen per plugin ==="
grep -n "plugin_connect_all" $D/mupen64plus-core/src/plugin/plugin.c
echo "--- body ---"
awk "/void plugin_connect_all/,/^}/" $D/mupen64plus-core/src/plugin/plugin.c | head -70
