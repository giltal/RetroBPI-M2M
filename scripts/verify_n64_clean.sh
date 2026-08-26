#!/bin/sh
T=$HOME/bpi/output/target/usr/lib/libretro/paralleln64_libretro.so
echo "core size : $(wc -c < $T)"
echo "core md5  : $(md5sum $T | cut -d' ' -f1)"
echo "--- instrumentation markers (all must be 0) ---"
for m in 'RAW n=' 'OUT n=' 'astick.log' 'glitch.log' 'speed_permille' 'XAXIS'; do
  printf '  %-16s %s\n' "$m" "$(strings $T | grep -c "$m")"
done
echo "--- real fixes still present ---"
D=$(ls -d $HOME/bpi/output/build/libretro-paralleln64-*/)
echo "  headroom gain : $(grep -c 'AUDIO_HEADROOM_GAIN);' $D/mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c)"
echo "  48k target    : $(grep -c 'AUDIO_TARGET_RATE / GameFreq' $D/mupen64plus-core/src/plugin/audio_libretro/audio_backend_libretro.c)"
echo "  declared 48k  : $(grep -c 'sample_rate = 48000.0' $D/libretro/libretro.c)"
echo "  astick_probe  : $(grep -c astick_probe $D/mupen64plus-core/src/plugin/emulate_game_controller_via_libretro.c) (must be 0)"
