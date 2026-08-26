D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== core audio implementation ==="
grep -rn "init_audio_libretro\|audio_batch_cb\|AUDIO_BUFFER" $D/libretro/*.c $D/libretro/*.h 2>/dev/null | head -20
echo "=== audio plugin files ==="
ls $D/libretro/ | head -30
