D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== where init_audio_libretro is defined ==="
grep -rn "init_audio_libretro" $D --include=*.c --include=*.h | grep -v "libretro/libretro.c"
echo "=== audio plugin dir ==="
ls -d $D/mupen64plus-audio-* 2>/dev/null; ls $D/mupen64plus-audio-*/ 2>/dev/null | head -20
