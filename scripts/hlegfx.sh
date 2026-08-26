D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== CFG_HLE_GFX definition and uses ==="
grep -rn "CFG_HLE_GFX" $D --include=*.c --include=*.h | head -20
echo "=== gfx function table assignments (processDList / processRDPList) ==="
grep -rn "gfx\.processDList\|gfx\.processRDPList\|processRDPList =\|processDList =" $D --include=*.c | head -20
