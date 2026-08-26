D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== where gfx.processDList / processRDPList get assigned ==="
grep -rn "processDList\|processRDPList" $D --include=*.c --include=*.h | grep -v "rsp_info" | head -20
echo "=== rsp_plugin selection / plugin_connect ==="
grep -rn "rsp_plugin" $D/libretro/libretro.c | head -20
