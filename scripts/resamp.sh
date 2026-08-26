D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== resampler quality options ==="
grep -rn "RESAMPLER_QUALITY" $D/libretro-common/include/audio/audio_resampler.h 2>/dev/null | head
echo "=== what rate does the game actually use? (GameFreq from AI dacrate) ==="
grep -n "GameFreq" $D/mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c
echo "=== retro_resampler_realloc signature ==="
grep -rn "retro_resampler_realloc" $D/libretro-common/include/audio/audio_resampler.h 2>/dev/null
