D=$(ls -d ~/bpi/output/build/libretro-paralleln64-*/)
echo "=== declared sample_rate in retro_get_system_av_info ==="
grep -n -A14 "void retro_get_system_av_info" $D/libretro/libretro.c | head -24
echo "=== any other sample_rate / 44100 / 48000 refs ==="
grep -rn "sample_rate\|44100\|48000" $D/libretro/libretro.c | head -12
